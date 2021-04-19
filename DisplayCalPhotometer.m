function DisplayCalPhotometer
close all; clc;
flop = 0;
while flop == 0
    title = 'Display Gamma Correction';
    prompt = {'Number of Measures (9,17,33 etc)', 'Screen ID'};
    defs = {'17', '0'};
    dispInfo = inputdlg(prompt, title, 1, defs);
    numMeasures = str2double(dispInfo{1});
    screenid = str2double(dispInfo{2});
    KbName('UnifyKeyNames');
    [gammaTable1, gammaTable2, displayBaseline, displayRange, displayGamma, maxLevel] = CalibrateMonitorPhotometer(numMeasures, screenid);%#ok
    prompt = 'Please, choose which model better fits the data (look the plot)';
    answer = questdlg(prompt, title, 'Gamma model', 'Spline Interpolation', 'Redo Measures', 'Redo Measures');
    filename = inputdlg('Type the name of the Monitor', 'Gamma Table File Name');
    if strcmp(answer, 'Gamma model')
        gammaTable = gammaTable1;
        save([filename{:} '_gammaTable_' date], 'gammaTable', 'displayBaseline', 'displayRange', 'displayGamma', 'maxLevel');
        flop = 1;
        msgbox(['New Gamma Table Saved in ' savedir]);
    elseif strcmp(answer, 'Spline Interpolation')
        savedir = uigetdir(pwd, 'Choose directory to save Gamma Table');
        cd(savedir);
        gammaTable = gammaTable2;
        save([filename{:} '_gammaTable_' date], 'gammaTable', 'displayBaseline', 'displayRange', 'displayGamma', 'maxLevel');
        flop = 1;
        msgbox(['New Gamma Table Saved in ' savedir]);
    else
        close all
        disp('Repeating measurements...');
    end
end
close all;clc;
return