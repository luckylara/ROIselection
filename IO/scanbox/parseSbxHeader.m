function config = parseSbxHeader(File)
% File can be a .mat info file, a .sbx file, a directory to prompt from, or
% an empty matrix to initiate file selection from the default directory

% config.version = 1;
directory = cd;

%% Check input arguments
narginchk(0,1);
if ~exist('File', 'var') || isempty(File)
    [File, p] = uigetfile({'.sbx;.mat'}, 'Choose sbx file', directory);
    if isnumeric(File)
        return
    end
    File = fullfile(p, File);
elseif isdir(File)
    [File, p] = uigetfile({'.sbx;.mat'}, 'Choose sbx file', File);
    if isnumeric(File)
        return
    end
    File = fullfile(p, File);
end


%% Load in header
[~, ~, e] = fileparts(File);
switch e
    case '.mat'
        ConfigFile = File;
        temp = sbxIdentifyFiles(File);
        SbxFile = temp{1};
    case '.sbx'
        SbxFile = File; % assumes sbx file to have same name and be located on same path
        temp = sbxIdentifyFiles(File);
        ConfigFile = temp{1};
end


%% Set identifying info
config.type = 'sbx';
config.FullFilename = SbxFile;
[~, config.Filename, ~] = fileparts(config.FullFilename);


%% Identify header information from file

% Load header
load(ConfigFile, 'info');

% Save header
config.header = {info};

% Save frame width
if isfield(info,'scanbox_version') && info.scanbox_version >= 2
    try
        config.Width = info.sz(2);
    catch
        config.Width = 796;
    end
else
    info.scanbox_version = 1;
    info.Width = info.postTriggerSamples;
end

% Determine frame rate
if info.scanbox_version>=2
    if isfield(info,'scanmode') && info.scanmode==0
        config.Height = info.recordsPerBuffer*2;
        config.FrameRate = 30.98;
    else
        config.Height = info.recordsPerBuffer;
        config.FrameRate = 15.49; % dependent upon mirror speed
    end
else
    config.Height = info.recordsPerBuffer;
    config.FrameRate = 15.49;
end

% Determine # of channels
switch info.channels
    case 1
        config.Channels = 2;      % both PMT0 & 1
    case 2
        config.Channels = 1;      % PMT 0
    case 3
        config.Channels = 1;      % PMT 1
end

% Determine # of depths
if ~isfield(info,'otwave') || isempty(info.otwave) || ~info.volscan
    config.Depth = 1;
    config.ZStepSize = 0;
    config.FramesPerDepth = 1;
else
    Depths = unique(info.otwave_um);
    config.Depth = numel(Depths);
    config.ZStepSize = info.otwave_um;
    config.FramesPerDepth = arrayfun(@(x) nnz(info.otwave_um==Depths(x)), 1:numel(Depths));
end

% Determine # of frames
d = dir(SbxFile);
config.Frames =  d.bytes/(config.Height*config.Width*config.Channels*2); % "2" b/c assumes uint16 encoding => 2 bytes per sample
    
% Determine magnification
config.ZoomFactor = info.config.magnification;


%% DEFAULTS
config.Precision = 'uint16'; % default
config.DimensionOrder = {'Channels','Width','Height','Depth','Frames'}; % default
config.Colors = {'green', 'red'};
config.size = [config.Height, config.Width, config.Depth, config.Channels, ceil(config.Frames/config.Depth)];


