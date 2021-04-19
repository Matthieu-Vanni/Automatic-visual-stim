function gammaTable = loadGammaTable(maindir)

title = 'Display Gamma Correction';
prompt = 'Load Gamma Table ?';
answer = questdlg(prompt, title, 'Yes', 'No', 'Do it Now', 'No');
switch answer
    case 'Yes'
        [gammaTab, gammaPath] = uigetfile('*.mat', 'Choose Gamma Table File');
        a = load(fullfile(gammaPath,gammaTab));
        gammaTable = a.gammaTable;
        disp('Gamma Table loaded in the workspace.')
    case 'Do it Now'
        if ~exist(fullfile(maindir, 'GammaTables'), 'dir')
            mkdir(fullfile(maindir, 'GammaTables'));
        end
        cd(fullfile(maindir, 'GammaTables'))
        DisplayCalPhotometer
        [gammaTab, gammaPath] = uigetfile('*.mat', 'Choose Gamma Table File');
        a = load(fullfile(gammaPath,gammaTab));
        gammaTable = a.gammaTable;
        disp('Gamma Table loaded in the workspace.')
    case 'No'
        gammaTable = [];
end
end