clear; close all; clc
maindir = uigetdir(pwd,'Choose the Directory where the Retinotopy functions are!');
addpath(genpath(maindir));
cd(maindir);
%% Select the screen ID:
% Screen ID is 0 when there is only one Monitor is connected.
screenid = 1;
%% Load/Create Gamma Table for Display Gamma Correction
gammaTable = loadGammaTable(maindir);

%% Load/Create Spherical Correction File
[warpfile, VD] = loadSphericalCorrFile(maindir);

%% Stimulation  Parameters
prompt = {'Number of sweeps (per Direction):', 'Time between sweeps (s):' , 'Bar size(deg):', 'Bar speed (deg/s):',...
    'Bar direction (0-90-180-270 (type -1 for ALL directions):', 'Checkerboard flickering frequency (Hz):', 'Checkerboard square size (deg);', 'Mouse ID (RIFD):'};
definput = {'20','5','20','9','-1','6', '25','Algernoon'};
dlgtitle = 'Stimulation Parameters';
dims = [1 50];
answer = inputdlg(prompt,dlgtitle,dims,definput);
varNames = {'nTrials', 'interStimTime', 'BarSize', 'DriftSpeed', 'DriftDirection', 'CheckerFreq', 'CheckerSize', 'MouseID'};
for i = 1:length(answer)-1
    eval([varNames{i} ' = ' answer{i} ';'])
end
MouseID = answer{end};
if ~ismember(DriftDirection, [0:90:270 -1])
    uiwait(warndlg('Attention! Oblique Drift angles may break the stimulus!', 'modal'))
end
%% Stimulus Presentation
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
 %% Sauvegarde des données
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

nomMaster = [MouseID suffix '_' t '.mat'];
save(nomMaster, 'nTrials', 'interStimTime', 'BarSize', 'DriftSpeed', 'DriftDirection', 'CheckerFreq', 'CheckerSize', 'MouseID')
disp('Data saved!')

