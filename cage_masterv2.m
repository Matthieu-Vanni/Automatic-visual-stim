%% Cage master v2
% Author : Enzo Delamarre - LabVanni
% Functions used/Inspired by : Bruno Souza/Véronique Chouinard - LabVanni
% Description : Main script, controls the visual stimulation system of the
% automatic cages. 2019-2021
% Last modified on : 18/04/2021

%% Parameters
clear; close all; clc
fixationDuration = 30;
screenid = 1; 
maindir = 'C:\Users\taches-comportements\Downloads\StimVisuellesCA\StimVisuellesCA';
addpath(genpath(maindir)); 

%% GUI - stimulataion mode choice
prompt = {'Mice fixation time (s) :','Cage number : '};
definput = {'30', '1'};
dlgtitle = 'Automatic cages parameters';
dims = [1 50];
answer = inputdlg(prompt,dlgtitle,dims,definput);
fixationDuration = str2double(answer{1});
cageNumber = str2double(answer{2});
answerm = questdlg('Choose the stimulation mode ', ...
	'Automatic cages visual stimulation', ...
	'Retinotopy','Gratings sequence','Both (randomly)', 'Both (randomly)');
% Handle response
switch answerm
    case 'Retinotopy' 
        stim = 1;
    case 'Gratings sequence'  
        stim = 2;
    case 'Both (randomly)'     
        stim = 0;
end
mouseID = cageNumber; % TODO : Handle mouse RFID with RFID reader in real time. 
%% Load/Create Gamma Table for Display Gamma Correction
gammaTable = loadGammaTable(maindir);

%% Load/Create Spherical Correction File
[warpfile, VD] = loadSphericalCorrFile(maindir);

%% GUI - Retino
if stim == 1 || stim ==0
    prompt = {'Number of sweeps (per Direction):', 'Time between sweeps (s):' , 'Bar size(deg):', 'Bar speed (deg/s):',...
        'Bar direction (0-90-180-270 (type -1 for ALL directions):', 'Checkerboard flickering frequency (Hz):', 'Checkerboard square size (deg);'};
    definput = {'20','5','20','9','-1','6', '25'};
    dlgtitle = 'Stimulation Parameters (Retinotopy)';
    dims = [1 50];
    answer = inputdlg(prompt,dlgtitle,dims,definput);
    varNames = {'nTrials', 'interStimTime', 'BarSize', 'DriftSpeed', 'DriftDirection', 'CheckerFreq', 'CheckerSize'};
    for i = 1:length(answer)
        eval([varNames{i} ' = ' answer{i} ';'])
    end
    if ~ismember(DriftDirection, [0:90:270 -1])
        uiwait(warndlg('Attention! Oblique Drift angles may break the stimulus!', 'modal'))
    end
end
%% Parameters - Gratings
if stim == 2 || stim ==0
    promptg = {'Number of trials:', 'Interstim time (s):' , 'Spatial frequency [cycles/degree)(type -1 for ALL frequencies) :', 'Temporal frequency (Hz)(type -1 for ALL frequencies :',...
        'Angle direction (degreees) (type -1 for ALL directions):'};
    definputg = {'1','0.5','-1','-1','-1'};
    dlgtitlge = 'Stimulation Parameters (Gratings)';
    dims = [1 50];
    answerg = inputdlg(promptg,dlgtitlge,dims,definputg);
    varNamesg = {'nTrials', 'interStimTime', 'SF', 'TF', 'angDir'};
    for i = 1:length(answerg)
        eval([varNamesg{i} ' = ' answerg{i} ';'])
    end

    %SF = [.02 .04 .08 .16 .32]; % Spatial Frequency in cycles per degree.
    % TF = [ 2 4  8 15 24];  % Temporal Frequency in Hz. 
    C = 1;        % Contrast (0-1).            
    % angDir = [0 90 180 270];  % in degrees.         
    % nTrials = 2;  % number of trials. 
    interstimDuration = interStimTime;  % in seconds.
    if SF == -1 
        SF = [.02 .04 .08 .16 .32];
    end
    if TF == -1 
        TF = [ 2 4  8 15 24];
    end
    if angDir == -1 
         angDir = [0 90 180 270];
    end
    stimDuration = fixationDuration;       % in seconds.    
end  
%% Infinite loop
while true
    if stim == 0 
        stim = randi([1 2]); % Random choice between retinotopy (1) and gratings (2)
    end
    if stim == 1
        %% Retinotopy

        if DriftDirection ~= -1
            [updatedtime,updatedrate, DeltaTime] = retino_episodic(screenid, gammaTable, warpfile, BarSize, DriftSpeed, DriftDirection, ...
            CheckerSize, CheckerFreq, nTrials, interStimTime, VD);
        else
            [updatedtime,updatedrate, DeltaTime] = retino_episodicAllDir(screenid, gammaTable, warpfile, BarSize, DriftSpeed, ...
            CheckerSize, CheckerFreq, nTrials, interStimTime, VD);
        end
        disp(['Real total presentation time: ' num2str(updatedtime) ' seconds.']);
        disp(['Real presentation frame rate: ' num2str(updatedrate) ' Hz.']);
        TimeOffset = round(DeltaTime - updatedtime);
        if TimeOffset ~=0
            warndlg(['There is an error of ' num2str(TimeOffset) ' seconds from the expected stimulus presentation duration. Check for Sync errors in PsychToolbox output.'], 'There is a problem!', 'modal')
        end

        %% Data saving
        t = char(datetime('now','TimeZone','local','Format','yyyy-MM-dd'));
        pathMaster = uigetdir(pwd, 'Save Directory');
        cd(pathMaster);

        switch DriftDirection
            case 0
                suffix = '_retino_GD';
            case 90
                suffix = '_retino_BH';
            case 180
            suffix = '_retino_DG';
            case 270
                suffix = '_retino_HB';
            case -1
                suffix = '_retino_AllDir';
            otherwise
                suffix = ['_retino_' num2str(DriftDirection) 'deg'];
        end
        MouseID = 'test';
        nomMaster = [MouseID suffix '_' t '.mat'];
        save(nomMaster, 'nTrials', 'interStimTime', 'BarSize', 'DriftSpeed', 'DriftDirection', 'CheckerFreq', 'CheckerSize', 'MouseID')
        disp('Data saved!')
        
        % Ajouter saving to text file
    else  
        %% Gratings
        TrialList = CreateTrialList(SF, TF, C, angDir, nTrials); % Creates a Block-randomized list of trials.
        [updatedtime, updatedrate, DeltaTime] = drifting_gratings_FF(screenid, gammaTable,warpfile, TrialList, interstimDuration, stimDuration, VD);
        disp(['Real total presentation time: ' num2str(updatedtime) ' seconds.']);  
        disp(['Real presentation frame rate: ' num2str(updatedrate) ' Hz.']);
        if round(DeltaTime - updatedtime) ~=0
            warndlg('The timing of your stimulus seems wrong! Check for Sync errors in PsychToolbox output.', 'There is a problem!', 'modal')
        end
        %% Data saving
        t = string(datetime('now','TimeZone','local','Format','yyyy-MM-dd'));
       %t = string(datetime(Y,M,D,H,MI,S));
        pathMaster = uigetdir(pwd, 'Save Directory');
        cd(pathMaster);

        nomMaster =  [MouseID suffix '_' t '.mat'];
        save(nomMaster, 'SF', 'TF', 'C', 'angDir', 'TrialList', 't');
        % Ajouter saving to text file
        
    end
end


