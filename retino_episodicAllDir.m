function [updatedtime,updatedrate, DeltaTime] = retino_episodicAllDir(scrID, GammaTable, dispwarpfilename, BarSize, DriftSpeed, ...
    CheckerSize, CheckerFreq, nTrials, interStimTime, VD)
sca; close all;

%%%%%
% Based on Marshel et al. 2011

%%%%%

% Initialize Arduino COM.
% a = arduino('COM8', 'ProMini328_5V'); % Uncomment if you want to use Arduino to trigger stim and mark timing.
%

% Check Display Sync . See "help PsychDefaultSetup" for more details.
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 1);
% Get the screen ID. If there is more than one, it makes an arbitrary selection.
if isempty(scrID)
    scrID = max(Screen('Screens'));
end
% Get pixel values for White, black and gray.
white = WhiteIndex(scrID);
black = BlackIndex(scrID);
gray = mean([white,black]);
if gray ~= .5
    gray = round(mean([white black]));
end
% Sets the background color of the screen
bcg = gray;
% Keybpard setup
%KbName('UnifyKeyNames'); % Not Necessary if PsychDefaultSetup(1);
spaceKey = KbName('space');
escapeKey = KbName('ESCAPE');
RestrictKeysForKbCheck([spaceKey escapeKey]);
% The gratings rotate inside the aperture:

try
    if ~isempty(dispwarpfilename)
        PsychImaging('PrepareConfiguration');
        PsychImaging('AddTask', 'AllViews', 'GeometryCorrection',dispwarpfilename);
    end
    
    % Open blank Window
    [win, winRect] = PsychImaging('OpenWindow', scrID, bcg,[], 32, 2, [], [], kPsychNeed32BPCFloat);
    AssertGLSL;
    % Check if we will apply the Gamma correction.
    if ~isempty(GammaTable)
        Screen('LoadNormalizedGammaTable', win, GammaTable*[1 1 1]);
    end
    % Set up alpha-blending for smooth (anti-aliased) lines
    Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    % Measure the vertical refresh rate of the monitor
    ifi = Screen('GetFlipInterval', win);
    topPriorityLevel = MaxPriority(win);
    
    [res_x, res_y] = Screen('WindowSize', win);
    % Grosseur de l'�cran (mm)
    [width, ~] = Screen('DisplaySize', scrID);
    % Monitor size and position variables
    w = width/10;  % width of screen, in cm
    
    [xCenter,yCenter]= RectCenter(winRect);
    %%% Transformation from degrees to pixel units.
    theta = 2*atand(w/2/VD);
    pxPerDeg = res_x/theta;
    BarSize = round(BarSize * pxPerDeg);
    CheckerSize = round(CheckerSize * pxPerDeg);
    DriftSpeed = DriftSpeed * pxPerDeg;
    DriftStep = round(DriftSpeed * ifi);
    %%%% Create checkerboard image
    
    I = double(checkerboard(CheckerSize,round(res_y/CheckerSize),round(res_x/CheckerSize))>0.5);
    I = I.* white;
    checktex(1) = Screen('MakeTexture', win, I);
    checktex(2) = Screen('MakeTexture', win, 1-I);
    CheckFlipFr = round(1/(CheckerFreq*ifi));
    %%%%  Create Bar Mask
    halfbar = round(BarSize/2);
    
    maskAzim = ones(res_y,res_x,2);
    maskAzim(:,:,1) = gray;
    centerx = round(size(maskAzim,2)/2);
    maskAzim(:,centerx - halfbar: centerx + halfbar,2) = 0;
    stepAzim = 1-halfbar:DriftStep:res_x + halfbar;
    stepAzim = fliplr(stepAzim);
    
    maskElev = ones(res_x,res_y,2);
    maskElev(:,:,1) = gray;
    centery = round(size(maskElev,2)/2);
    maskElev(:,centery - halfbar: centery + halfbar,2) = 0;
    stepElev = 1-halfbar:DriftStep:res_y + halfbar;
    
    masktexAzim = Screen('MakeTexture', win, maskAzim);
    masktexElev = Screen('MakeTexture', win, maskElev);
    
    baseRectAzim = SetRect(0,0,size(maskAzim,2), size(maskAzim,1));
    baseRectAzim = CenterRectOnPoint(baseRectAzim,xCenter,yCenter);
    
    baseRectElev = SetRect(0,0,size(maskElev,2), size(maskElev,1));
    baseRectElev = CenterRectOnPoint(baseRectElev,xCenter,yCenter);
    
    % Number of frames between FLIPS. For instance, we can set "waitframes = 2" in order ...
    % to get an approximate frame rate of 30 Hz, given that the refresh rate of ...
    % the monitor is 60 Hz.
    waitframes = 1;
    interstim_durationframes = round(interStimTime/ifi);
    % Hide mouse cursor
    HideCursor();
    
    tinyRect = 60;
    offsetX = 40;
    offsetY = 140;
    Screen('FillRect', win, gray);
    Screen('FillRect', win, black, [offsetX offsetY tinyRect + offsetX tinyRect + offsetY]);
    Screen('Flip', win);
    
    % Arduino Control:
    % Wait for trigger from Labeo System.
    % Uncomment if you want to use Arduino to trigger stim and mark timing.%     
%     T = 0;
%          while T ==0
%              trigg = readDigitalPin(a,'D4');
%              if trigg == 1
%                  T = 1;
%             end
%         end
    % Manual wait...
    [~, keyCode, ~] = KbWait();
    while keyCode(spaceKey) == 0
       [~, keyCode, ~] = KbWait();
    end
    
    
    %     movPtr=Screen('CreateMovie', win, 'retinoMov3.mov', [],[],60,':CodecType=theoraenc', 1); % Uncomment this if you want to save your stimulus as a movie.
    Priority(topPriorityLevel);
    
    flop = [1 2];
    count = 0;
    vbl = Screen('Flip', win);
    tstart  = GetSecs();
    DirArray = 0:90:270;
    idxDir = 1;
    while idxDir <= length(DirArray)
        i=1;
        t=1;
        jj = 1;
        if DirArray(idxDir) == 0 || DirArray(idxDir) == 180
            masktex = masktexAzim;
            step = stepAzim;
            baseRect = baseRectAzim;
        else
            masktex = masktexElev;
            step = stepElev;
            baseRect = baseRectElev;
        end
        while jj <= nTrials
            InterStimFrameCounter = 0;
            while InterStimFrameCounter < interstim_durationframes
                Screen('FillRect', win, bcg, winRect);
                Screen('FillRect', win, black, [offsetX offsetY tinyRect + offsetX tinyRect + offsetY]);
                Screen('Flip', win, vbl + (waitframes - 0.5) * ifi);
                %             Screen('AddFrameToMovie', win); % Uncomment this if you want to save your stimulus as a movie.
                InterStimFrameCounter = InterStimFrameCounter + 1;
                count = count + 1;
            end
            while i <=length(step)
                if t == CheckFlipFr
                    flop = fliplr(flop);
                    t = 1;
                end
                maskRect = CenterRectOnPoint(baseRect, step(i), yCenter);
                Screen('DrawTexture', win, checktex(flop(1)), winRect);
                Screen('DrawTexture', win, masktex, maskRect,[], DirArray(idxDir));
                Screen('FillRect', win, white, [offsetX offsetY tinyRect + offsetX tinyRect + offsetY]);
                vbl = Screen('Flip', win, vbl + (waitframes - 0.5) * ifi);
                %         Screen('AddFrameToMovie', win);% Uncomment this if you want to save your stimulus as a movie.
                i = i+1;
                t = t+1;
                count = count + 1;
            end
            i = 1;
            jj = jj + 1;
            if KbCheck
                break;
            end
        end
        idxDir = idxDir + 1;
    end
    %     Screen('FinalizeMovie', movPtr);% Uncomment this if you want to save your stimulus as a movie.
    
    tstop = GetSecs();
    Priority(0);
    DeltaTime = tstop - tstart;
    Screen('FillRect', win, black);
    Screen('Flip', win);
    [~, keyCode, ~] = KbWait();
    while keyCode(escapeKey) == 0
        FlushEvents();
        [~, keyCode, ~] = KbWait();
    end
    Screen('CloseAll');
    RestoreCluts();
    clear mex;%#ok
    
    updatedtime = count*ifi;
    updatedrate = count/updatedtime;
    
catch
    Screen('CloseAll');
    psychrethrow(psychlasterror);
    sca;
end
end