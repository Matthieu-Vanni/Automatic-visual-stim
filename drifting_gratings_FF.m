function [updatedtime, updatedrate, DeltaTime] = drifting_gratings_FF(scrID, GammaTable,dispwarpfilename, ...
    TrialList, interstimDuration, stimDuration, VD)
% DRIFTING_GRATINGS_FF Presents full field drifting gratings.

sca; close all;

%%%%%

% Initialize Arduino COM.
% a = arduino('COM8', 'ProMini328_5V'); % Uncomment if you want to use Arduino to trigger stim and mark timing.
%

% Check Display Sync . See "help PsychDefaultSetup" for more details.
PsychDefaultSetup(1);
% PsychDefaultSetup(2);
% Screen('Preference', 'VisualDebugLevel', 0);
% Screen('Preference','SuppressAllWarnings', 1);
% Screen('Preference', 'SkipSyncTests', 1);
% Get the screen ID. If there is more than one, it makes an arbitrary selection.
if isempty(scrID)
    scrID = max(Screen('Screens'));
end
% Get pixel values for White, black and gray.
white = WhiteIndex(scrID);
black = BlackIndex(scrID);
gray = round(mean([white,black]));
% Sets the background color of the screen
bcg = gray;
spaceKey = KbName('space');
escapeKey = KbName('ESCAPE');
RestrictKeysForKbCheck([spaceKey escapeKey]);

try
    if ~isempty(dispwarpfilename)
        PsychImaging('PrepareConfiguration');
        PsychImaging('AddTask', 'AllViews', 'GeometryCorrection',dispwarpfilename);
    end
    % The gratings rotate inside the aperture:
    rotateMode = kPsychUseTextureMatrixForRotation;
    % Open blank Window
    [win, winRect] = PsychImaging('OpenWindow', scrID, bcg);
    
    % Check if we will apply the Gamma correction.
    if ~isempty(GammaTable)
        Screen('LoadNormalizedGammaTable', win, GammaTable*[1 1 1]);
    end
    %     AssertGLSL;
    % Measure the vertical refresh rate of the monitor
    ifi = Screen('GetFlipInterval', win);
    topPriorityLevel = MaxPriority(win);
    [res_x, ~] = Screen('WindowSize', win);
    
    % Grosseur de l'?cran (mm)
    [width, ~] = Screen('DisplaySize', scrID);
    % Monitor size and position variables
    w = width/10;  % width of screen, in cm
    % Parameters for grating creation:
    xlen = ceil(res_x*2); % make the grating twice the size to avoid jitters.
    x = 1:xlen;
    theta = 2*atan2(w/2,VD)*180/pi;
    fc = theta/w; fcdp = fc*w/res_x;
    
    % Number of frames between FLIPS. For instance, we can set "waitframes = 2" in order ...
    % to get an approximate frame rate of 30 Hz, given that the refresh rate of ...
    % the monitor is 60 Hz.
    waitframes = 1;
    waitduration = waitframes * ifi;
    
    % Recompute p, this time without the ceil() operation from above.
    % Otherwise we will get wrong drift speed due to rounding!
    % pixels/cycle
    
    % Translate requested speed of the grating (in cycles per second)
    % into a shift value in "pixels per frame", assuming given
    % waitduration: This is the amount of pixels to shift our "aperture" at
    % each redraw:
    
    interstim_durationframes = round(interstimDuration/ifi);
    stim_durationframes = round(stimDuration/ifi);
    
    % Hide mouse cursor
   % HideCursor();
    
    % Perform initial Flip and sync us to the retrace:
    Priority(topPriorityLevel);
    vbl = Screen('Flip', win);
    % Rectangle at the corner of the screen
    tinyRect = 0; % size in pixels
    % If using spherical correction, the Rectangle may fall outside the
    % screen. Change offset lengths to correct it.
    offsetX = 20; % horizontal offset in pixels
    offsetY = 200; % vertical offset in pixels
    
    count = 0;
    Screen('FillRect', win, gray);
    Screen('FillRect', win, black, [offsetX offsetY tinyRect + offsetX tinyRect + offsetY]);
    Screen('Flip', win);
    
    % Arduino Control:
    % Wait for trigger from Labeo System. 
    % Uncomment if you want to use Arduino to trigger stim and mark timing.
%     T = 0;
%     while T ==0
%         trigg = readDigitalPin(a,'D4');
%         if trigg == 1
%             T = 1;
%         end
%     end

% Manual control 
    [~, keyCode, ~] = KbWait();
    while keyCode(spaceKey) == 0
        [~, keyCode, ~] = KbWait();
    end
    tstart  = GetSecs();
    for ii = 1:size(TrialList,1)
        
        i = 1;
        InterStimFrameCounter = 0;
        StimFrameCounter = 0;
        fpp = TrialList(ii,1)*fcdp;
        p=1/fpp;
        shiftperframe= TrialList(ii,2) * p * waitduration;
        Amp = TrialList(ii,3) * (white - gray);
        grating = gray + Amp * cos(2*pi*fpp.*x);
        gratingtex=Screen('MakeTexture', win, grating);
        ang = TrialList(ii,4);
         while StimFrameCounter < stim_durationframes
            
            % Shift the grating by "shiftperframe" pixels per frame:
            xoffset = mod(i*shiftperframe,p);
            i=i+1;
            % Define shifted srcRect that cuts out the properly shifted rectangular
            % area from the texture:
            srcRect=[xoffset 0 xoffset + xlen xlen];
            Screen('DrawTexture', win, gratingtex, srcRect, [], ang, [], [],[],[],rotateMode);
            Screen('FillRect', win, white, [offsetX offsetY tinyRect + offsetX tinyRect + offsetY]);
            
            % Show it at next retrace:
            vbl = Screen('Flip', win, vbl + 0.5 * ifi);
            StimFrameCounter= StimFrameCounter + 1;
            count = count + 1;
        end
        while InterStimFrameCounter < interstim_durationframes
            Screen('FillRect', win, bcg, winRect);
            Screen('FillRect', win, black, [offsetX offsetY tinyRect + offsetX tinyRect + offsetY]);
            Screen('Flip', win, vbl + (waitframes - 0.5) * ifi);
            InterStimFrameCounter = InterStimFrameCounter + 1;
            count = count + 1;
        end
    end
    
    Screen('FillRect', win, black);
    Screen('Flip', win);
    tstop = GetSecs();
    Priority(0);
    DeltaTime = tstop - tstart;
%     [~, keyCode, ~] = KbWait();
%     while keyCode(escapeKey) == 0
%         FlushEvents();
%         [~, keyCode, ~] = KbWait();
%     end
    Screen('CloseAll');
    RestoreCluts();
    clear mex;%#ok
    
    updatedtime = count*ifi;
    updatedrate = count/updatedtime;
    sca;
    
catch
    Screen('CloseAll');
    psychrethrow(psychlasterror);
    sca;
end
end