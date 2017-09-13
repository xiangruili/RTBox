function [availPorts, busyPorts] = FindSerialPorts(VCPOnly, availOnly)
% ports = FindSerialPorts(1, 0); % all VCP regardless of availability
% [availPorts, busyPorts] = FindSerialPorts(); % separate avail/busy ports
% 
% Return serial port names in cell string, used by IOPort, such as
%  handle = IOPort('OpenSerialPort', availPorts{1}). 

% The second output contains port names which are unavailable to IOPort, either
% used by other user program or by OS. 

% The first optional input tell whether to return USB-serial ports only
% (default), or all serial ports. The second optional input tell whether to
% separate available and busy ports (default), or return all ports. IOPort is
% not needed if to return all ports.
% 
% Example to open a USB-serial port automatically:
%  ports = FindSerialPorts; % USBserial ports cellstr
%  nPorts = numel(ports); % number of ports
%  if nPorts == 0
%      error('No USB serial ports available.');
%  elseif nPorts>1
%      % If more than 1, will open 1st. You can choose another port by:
%      % ports{1} = ports{2}; % open 2nd instead of 1st
%      str = strrep(ports, '\\.\', ''); % remove Windows path
%      str = sprintf(' %s,' ,str{:});
%      warning(['Multiple ports available: %s\b. The first will be used.'], str);
%  end
%  handle = IOPort('OpenSerialPort', ports{1}); % open 1st in ports
 
% 080101 write it (Xiangrui Li)
% 170428 use reg query for Windows, rather than COM1:COM256
% 170430 add 2nd input arg, so return all ports regardless availability
% 170627 use 'Serial\d+' to exclude builtin ports under Windows.

if nargin<1 || isempty(VCPOnly), VCPOnly = true; end
if ispc
    ports = win_serial(VCPOnly);
    pth = '\\.\';
elseif ismac
    if VCPOnly, ports = dir('/dev/cu.usbserial*');
    else, ports = dir('/dev/cu*');
    end
    ports = {ports.name};
    pth = '/dev/';
elseif isunix
    ports = dir('/dev/ttyUSB*');
    if ~VCPOnly % does Linux have specific str for PCI ports?
        ports = [dir('/dev/ttyS*'); ports];
    end
    ports = {ports.name};
    pth = '/dev/';
else
    error('Unsupported system: %s.', computer);
end

availPorts = {}; busyPorts = {}; % assign empty cell, will grow later
if nargin>1 && ~logical(availOnly), availPorts = strcat(pth, ports); return; end

% Check if port is available by IOPort
verbo = IOPort('Verbosity', 0); % shut up screen output and error
for i = 1:numel(ports)
    port = [pth ports{i}];
    [h, errmsg] = IOPort('OpenSerialPort', port);
    if h >= 0  % open succeed
        IOPort('Close', h); % test only, so close it
        availPorts{end+1} = port; %#ok
    elseif isempty(strfind(errmsg, 'ENOENT')) %#ok fail to open but port exists
        busyPorts{end+1} = port; %#ok
    end
end
IOPort('Verbosity', verbo); % restore Verbosity

function ports = win_serial(VCPOnly)
% Return serial ports under Windows.
% ! mode, chgport can list ports, but too slow.
HLM = 'HKEY_LOCAL_MACHINE';
sub = 'HARDWARE\DEVICEMAP\SERIALCOMM';
try % winqueryreg is fast: ~1 ms
    ports = {};
    nams = winqueryreg('name', HLM, sub); % reg valueNames
    for i = 1:numel(nams)
        if VCPOnly && ~isempty(regexp(nams{i}, '\\Serial\d+', 'once'))
            continue;
        end
        ports{end+1} = winqueryreg(HLM, sub, nams{i}); %#ok<AGROW>
    end
catch % if no winqueryreg, fallback to reg query for Octave, ~ 60 ms
    [~, str] = system(['reg.exe query ' HLM '\' sub]);
    expr = 'REG_SZ\s+(COM\d{1,3})';
    if VCPOnly, expr = ['(?<!Serial\d+\s+)' expr]; end % no Serial0 etc
    ports = regexp(str, expr, 'tokens');
    for i = 1:numel(ports), ports{i} = ports{i}{1}; end
end
