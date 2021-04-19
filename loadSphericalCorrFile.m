function [filename, VD] = loadSphericalCorrFile(maindir)
cd(maindir);
title = 'Spherical Correction';
prompt = 'Load Spherical Correction File?';
answer = questdlg(prompt, title, 'Yes', 'No', 'Make a New One', 'No');
switch answer
    case 'Yes'
        [SphrCorrFileName, Path] = uigetfile('*.mat', 'Choose Gamma Table File');
        filename = fullfile(Path,SphrCorrFileName);
        a = matfile(filename);
        Params = a.DistParams;
        VD = Params.VD;
        answer2 = questdlg({['File Selected : ' filename], 'Parameters:', ['Viewing Distance (cm) : ' num2str(Params.VD)], ...
            ['Center X (cm) : ' num2str(Params.cx)], ['Center Y (cm): ' num2str(Params.cy)], 'PROCEED??'}, ...
            'Spherical Correction: Distances', 'Proceed', 'Cancel', 'Proceed');
        if strcmp(answer2, 'Cancel')
            filename = [];
        end
    case 'Make a New One'
        title = 'Parameters for Spherical correction';
        prompt = {'FileName', 'Screen ID', 'Viewing Distance (cm)',  'Center X (cm)', 'Center Y (cm)', 'Downsampling Factor'};
        defs = {'SphericalCorrection','0','13.5', '0' , '0', '10'};
        opts.Resize = 'on';
        dispInfo = inputdlg(prompt, title, 1, defs, opts);
        if isempty(dispInfo)
            return
        end
        genSphericalCorrectionFile(maindir,dispInfo{1}, str2double(dispInfo{2}), str2double(dispInfo{3}), str2double(dispInfo{4}), str2double(dispInfo{5}), str2double(dispInfo{6}))
        filename = fullfile(maindir, [dispInfo{1} '.mat']);
        VD = str2double(dispInfo{3});
    case 'No'
        filename = [];
        VD = inputdlg('Type the viewing distance (cm):', 'Viewing distance',1, {'13.5'});
        VD = str2double(VD);
end
end