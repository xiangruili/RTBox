function varargout = serIO(cmd, varargin)
% out = serIO('cmd', h, param)
% 
% This is a simple wrapper to use serFTDI and IOPort. Its syntax is the same as
% serFTDI which is used if available. If serFTDI is not available or fails to
% open a port, IOPort will be used.
% 
% See also: serFTDI, IOPort

% 171008 Write it (Xiangrui.Li at gmail.com)

persistent use_serFTDI clnObj; %#ok
if isempty(use_serFTDI)
    try
        if exist('OCTAVE_VERSION', 'builtin')
            [pth, nam, ext] = fileparts(which('serFTDI'));
            if strcmp(ext, '.m') % mex file not found
                mexNam = fullfile(pth, [nam '.mex']);
                if ispc,      copyfile([mexNam 'OctaveWin64'], mexNam);
                elseif ismac, copyfile([mexNam 'OctaveMac64'], mexNam);
                else,         copyfile([mexNam 'OctaveLnx64'], mexNam);
                end
                rehash path;
            end
        end
        use_serFTDI = serFTDI('Accessible');
    catch
        use_serFTDI = false;
    end
    if ~use_serFTDI
        verbo = IOPort('Verbosity', 0);
        clnObj = onCleanup(@() IOPort('Verbosity', verbo));
    end
end

if strcmp(cmd, 'use_serFTDI')
    if nargin>1, use_serFTDI = logical(varargin{1}); end
    if nargout, varargout{1} = use_serFTDI; end
    return;
end

if use_serFTDI
    [varargout{1:nargout}] = serFTDI(cmd, varargin{:});
    return;
end

% Fallback to IOPort
if strcmpi(cmd, 'Write')
    [~, tpost, ~, tpre] = IOPort(cmd, varargin{:});
    varargout = {tpre, tpost};
elseif strcmpi(cmd, 'Read')
    if nargin>2, [varargout{1:nargout}] = IOPort(cmd, varargin{1}, 1, varargin{2:end});
    else,        [varargout{1:nargout}] = IOPort(cmd, varargin{1});
    end
else % 
    if strcmpi(cmd, 'Open')
        cmd = 'OpenSerialPort';
        dft = ' BaudRate=115200 ReceiveTimeout=0.3';
        if nargin<3, varargin{2} = dft;
        else, varargin{2} = [varargin{2} dft];
        end
    elseif strcmpi(cmd, 'Configure')
        cmd = 'ConfigureSerialPort';
    end
    [varargout{1:nargout}] = IOPort(cmd, varargin{:});
end
