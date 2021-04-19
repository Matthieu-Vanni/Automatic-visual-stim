function genSphericalCorrectionFile(savedir,caliboutfilename, screenid, VD, cx, cy, subdivide)
% GENSPHERICALCORRECTIONFILE creates a .MAT file used by PSYCHTOOLBOX to
% perform the spherical correction. The File contains a structure (SCAL)
% with the remapped positions of monitor pixels simulating a spherical
% projection into a flat surface (the monitor).
% INPUTS:
% SAVEDIR : Directory where the file will be saved.
% CALIBOUTFILENAME : Name of Spherical Correction File (without the
% extension!)
% SCREENID : ID of monitor used to display visual stimulation.
% VD : Viewing distance. It is the distance from the animal's eye to the
% center of the monitor 
% SUBDIVIDE : Downsampling factor of pixel remapping. You can use > 1 if
% you experience lagging.

PsychDefaultSetup(0);
Screen('Preference', 'SkipSyncTests', 1);
if ~exist('screenid', 'var') || isempty(screenid)
    screenid = 0;
end
sca; close all;
win = PsychImaging('OpenWindow', screenid, 0); % Open black
[res_x, res_y] = Screen('WindowSize', win);
% Screen Size (mm)
[width, ~] = Screen('DisplaySize', screenid);
% Monitor size and position variable
width = width/10;  % width of screen, in cm

% Pixel/cm ratio
pxPerCm = res_x/width;

% Transform viewing distance (VD) from cm to pixel units:
VDpx = VD*pxPerCm;
CXpx = cx*pxPerCm;
CYpx = cy*pxPerCm;
sca;
try
    % At this point, screenid contains the final screenid for the screen to
    % calibrate. Assign it to scal struct. This will create 'scal' if it
    % doesn't exist yet, or override its screenid in some cases:
    scal.screenNumber = screenid;
    
    % Define type of mapping for this calibration method: This is used in the
    % CreateDisplayWarp() routine when parsing the calibration file to detect
    % the type of undistortion method to use, ie. how to interpret the data in
    % the calibration file to setup the calibration.
    warptype = 'CSVDisplayList';
    
    % We won't use normalized coordinates, but absolute pixel coordinates for
    % this method: Encoded source and target coordinates are absolute locations
    % in units of pixels
    scal.useUnitDisplayCoords = 0;
    
    % Use a subsampling of the dense calibration matrices of 10. Only every 10th
    % pixel in x and y direction is used to define the warpmesh, so we cut down
    % the amount of geometry to process to 1 / (10*10) = 1/100 th. Bilinear
    % interpolation is used for intermediate pixel locations. Tweak the subdivision
    % value to your needs aka your calibration accuracy <-> performance tradeoff.
    
    
    [xi, yi, xS, yS] = createDistortion(res_x, res_y, VDpx, CXpx, CYpx, subdivide);
    
    
    % Build 2D source and destination matrices: rows x cols per plane,
    % 2 planes for x and y components:
    rows = size(xi, 1);
    cols = size(xi, 2);
    
    % Vertex coordinates of the rendered output mesh quad vertices:
    scal.vcoords = zeros(rows, cols, 2);
    
    % Corresponding texture coordinates for sourcing from user provided input
    % image framebuffer:
    scal.tcoords = zeros(rows, cols, 2);
    
    % Assign from output of the Labrigger MouseStim implementation
    scal.vcoords(:,:,1) = xi;
    scal.vcoords(:,:,2) = yi;
    scal.tcoords(:,:,1) = xS;
    scal.tcoords(:,:,2) = yS;
    
    % 'scal' contains the final results of calibration. Write it out to
    % calibfile for later use by the runtime routines:
    
    % Check if name for calibration result file is provided:
    if ~exist('caliboutfilename', 'var')
        caliboutfilename = [];
    end
    
    if isempty(caliboutfilename)
        % Nope: Assign default name - Store in dedicated subfolder of users PTB
        % config dir, with a well defined name that also encodes the screenid
        % for which to calibrate:
        caliboutfilename = [ PsychtoolboxConfigDir('GeometryCalibration') 'CSVCalibdata' sprintf('_%i', screenid) '.mat'];
        fprintf('\nNo name for calibration file provided. Using default name and location...\n');
    end
    
    % Print name of calibfile and check for existence of file:
    fprintf('Name of calibration result file: %s\n\n', caliboutfilename);
    if exist(caliboutfilename, 'file')
        answer = input('This file already exists. Overwrite it [y/n]? ','s');
        if ~strcmpi(answer, 'y')
            fprintf('\n\nCalibration aborted. Please choose a different name for calibration result file.\n\n');
            return;
        end
    end
    % Gather Distance parameters in structure.
    DistParams.VD = VD;
    DistParams.cx = cx;
    DistParams.cy = cy;
    
    % Save all relevant calibration variables to file 'caliboutfilename'. This
    % method should work on both, Matlab 6.x, 7.x, ... and GNU/Octave - create
    % files that are readable by all runtime environments:
    save([savedir filesep caliboutfilename '.mat'], 'warptype', 'scal', 'DistParams', '-mat', '-V7.3'); % Modified by BrunoO (24.05.2019)
    
    fprintf('Creation of Calibration file finished :-)\n\n');
    fprintf('You can apply the calibration in your experiment script by replacing your \n')
    fprintf('win = Screen(''OpenWindow'', ...); command by the following sequence of \n');
    fprintf('commands:\n\n');
    fprintf('PsychImaging(''PrepareConfiguration'');\n');
    fprintf('PsychImaging(''AddTask'', ''LeftView'', ''GeometryCorrection'', ''%s'');\n', caliboutfilename);
    fprintf('win = PsychImaging(''OpenWindow'', ...);\n\n');
    fprintf('This would apply the calibration to the left-eye display of a stereo setup.\n');
    fprintf('Additional options would be ''RightView'' for the right-eye display of a stereo setup,\n');
    fprintf('or ''AllViews'' for both views of a stereo setup or the single display of a mono\n');
    fprintf('setup.\n\n');
    fprintf('The ''GeometryCorrection'' call has a ''debug'' flag as an additional optional parameter.\n');
    fprintf('Set it to a non-zero value for diagnostic output at runtime.\n');
    fprintf('E.g., PsychImaging(''AddTask'', ''LeftView'', ''GeometryCorrection'', ''%s'', 1);\n', caliboutfilename);
    fprintf('would provide some debug output when actually using the calibration at runtime.\n\n\n');
    sca;
    % Done.
    return;
    
catch
    Screen('CloseAll');
    psychrethrow(psychlasterror);
    sca;
end
end


function [y, z, xS, yS] = createDistortion(res_x, res_y, x, CXpx, CYpx, subdivide)
close all;

% Algorithm based on:
% Marshel, James H., Marina E. Garrett, Ian Nauhaus, and Edward M. Callaway. 
% ‘Functional Specialization of Seven Mouse Visual Cortical Areas’. 
% Neuron 72, no. 6 (22 December 2011): 1040–54. https://doi.org/10.1016/j.neuron.2011.12.004.

% ATTENTION!!
%   The calculation of spherical coordinates uses the following assumptions:
%   1) The spherical coordinate space is oriented such that the perpendicular
%      bisector from the eye to the monitor is the (0 deg,0 deg) axis of the
%      altitude/azimuth coordinates.
%   2) The perpendicular bisector from the eye to the monitor is located at
%   the center of the monitor.

[y,z] = meshgrid(0:res_x,0:res_y);
yi = y - CXpx;
zi = z - CYpx;
Elev = pi/2 - acos(zi./sqrt(x^2 + yi.^2 + zi.^2));
Azim = atan(yi./x);
%%%
xmaxRad = max(Azim(:));
ymaxRad = max(Elev(:));

fx = xmaxRad/max(yi(:));
fy = ymaxRad/max(zi(:));

% Compute matrices with sampling positions, needed for Psychtoolbox:
xS = interp2(yi.*fx,zi.*fy,y,Azim,Elev);
yS = interp2(yi.*fx,zi.*fy,z,Azim,Elev);

% Subsample to only use every subdivide'th sample:
y = y(1:subdivide:end, 1:subdivide:end);
z = z(1:subdivide:end, 1:subdivide:end);

xS = xS(1:subdivide:end, 1:subdivide:end);
yS = yS(1:subdivide:end, 1:subdivide:end);

end