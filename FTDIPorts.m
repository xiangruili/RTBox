function varargout = FTDIPorts(varargin)
% ports = FTDIPorts()
% Return all connected FTDI serial ports.

% 171011 Extract this from old RTBoxPorts. 

if nargin>1, [varargout{1:nargout}] = feval(varargin{:}); return; end
    
if serIO('use_serFTDI')
    varargout{1} = num2cell(0:serFTDI('NumberOfPorts')-1);
    return;
end

if     ispc,   varargout{1} = ftdi_vcp_win();
elseif ismac,  varargout{1} = ftdi_vcp_mac();
elseif isunix, varargout{1} = ftdi_vcp_lnx();
else, error('Unsupported system: %s.', computer);
end
%%

function ports = ftdi_vcp_lnx()
% Return FTDI serial ports under Linux.
ports = dir('/dev/ttyUSB*');
ports = {ports.name};
for i = numel(ports):-1:1
    ports{i} = ['/dev/' ports{i}];
    [~, str] = system(['udevadm info -an ' ports{i}]);
    ib = [regexp(str, '\n\n') numel(str)]; % empty line
    no0403 = true;
    for j = regexp(str, '{idProduct}=+"6001"') % likely only 1 block has '6001'
        k = find(ib>j, 1);
        iv = regexp(str(ib(k-1):ib(k)), '{idVendor}=+"0403"', 'once');
        if ~isempty(iv), no0403 = false; break; end
    end
    if no0403, ports(i) = []; end
end
%%

function ports = ftdi_vcp_mac()
% Return FTDI serial ports under OSX.
% The FTDI filtering on OSX is not reliable for now. There is no udevadm
% equivalent for OSX. Both ioreg and system_profiler can give USB info, but the
% issue is to link the info to a serial port. The port name cu.usbseral-xxxxxxxx
% has variants for differnt driver. For FTDI driver, it should be 8-digit hex
% location ID (but seems 4 bytes reversed). For Apple driver, I have seen
% 3-digit which seems from location ID without the trailing zeros. Some say
% those digits contain more info than location ID, but it seems it is not the
% case for FTDI ports.
% The current way to exclude a port from list is if:
%  location ID contains non-hex char, OR 
%  ID in port does not match the starting hex in location ID, and does not
%  match the reversed 4-byte location ID. 

% Based on: Location ID: 0x3d100000 / 1  ("locationID" / "USB Address")
[~, str] = system('ioreg -xl -p IOUSB'); % system_profiler SPUSBDataType
ib = [regexp(str, '\+-o') numel(str)]; % tree start
IDs = {}; % location IDs for FTDI USB-serial
expr = '"locationID"\s*=\s*0x([0-9a-fA-F]+)'; % 3d100000
for i = regexp(str, '"idProduct"\s*=\s*0x6001')
    k = find(ib>i, 1);
    iv = regexp(str(ib(k-1):ib(k)), '"idVendor"\s*=\s*0x0?403', 'once');
    if isempty(iv), continue; end
    a = regexp(str(ib(k-1):ib(k)), expr, 'tokens', 'once');
    IDs{end+1} = a{1}; %#ok<*AGROW>
end

ports = dir('/dev/cu.usbserial*');
ports = {ports.name};
for i = numel(ports):-1:1
    p = regexp(ports{i}, '(?<=-).*', 'match', 'once'); % 0000103D or 145
    ports{i} = ['/dev/' ports{i}];
    n = numel(p); % 8 for FTDI driver, likely 3 for Apple driver
    if n<3 || n>8, emailAuthor(sprintf('%s ', IDs{:}, ports{:})); end
    if ~isempty(regexp(p, '[^0-9a-fA-F]', 'once')) || ...
            (~any(strncmpi(IDs, p, n)) && ...
            (n>7 && ~any(strncmpi(IDs, p([7:8 5:6 3:4 1:2]), 8))))
        ports(i) = [];
    end
end
%%

function ports = ftdi_vcp_win()
% Return FTDI serial ports under Windows.
persistent PORTs;
HLM = 'HKEY_LOCAL_MACHINE';
sub = 'HARDWARE\DEVICEMAP\SERIALCOMM';
try % winqueryreg is fast: ~1 ms
    ports = {};
    nams = winqueryreg('name', HLM, sub); % list \Device\serial&VCP
    for i = 1:numel(nams)
        if isempty(strfind(nams{i}, 'VCP')), continue; end
        ports{end+1} = winqueryreg(HLM, sub, nams{i});
    end
catch % if no winqueryreg, fallback to reg query for Octave: ~60 ms
    [~, str] = system(['reg.exe query ' HLM '\' sub]);
    ports = regexp(str, 'VCP\d*\s+REG_SZ\s+(COM\d+)', 'tokens');
    ports = [ports{:}];
end

ftdiPorts = ftdi_registry(~isequal(PORTs, ports)); % PORTs changed?
PORTs = ports; % cach active ports
for i = numel(ports):-1:1 % can use intersect & strcat
    if ~any(strcmp(ports{i}, ftdiPorts)), ports(i) = []; continue; end
    ports{i} = ['\\.\' ports{i}];
end
%%

function emailAuthor(err)
a = dbstack;
if numel(a)>1, err = sprintf('In %s:\n%s', a(2).name, err); end
fprintf(2, '%s\n', err);
fprintf(2, 'Please email above error message to xiangrui.li at gmail.com\n');
%%

function val = regquery(key, nam)
% Query the registry value of 'nam' in 'key'.
% Call winqueryreg if available, otherwise use Windows reg query.
if exist('winqueryreg', 'file')
    try
        keys = regexp(key, '\\', 'split', 'once');
        val = winqueryreg(keys{:}, nam);
        if isnumeric(val), val = double(val); end
    catch, val = []; % nam not exist, avoid error
    end
else
    [~, str] = system(['reg.exe query "' key '" /v ' nam]);
    tok = regexp(str, [nam '\s+(REG_\w+)\s+(\w+)'], 'tokens', 'once');
    if numel(tok)<2, val = []; return; end
    val = tok{2};
    if ~isempty(strfind(tok{1}, '_SZ')), return; end % char type
    if strncmp(val, '0x', 2), val = sscanf(val, '0x%x'); % always hex type?
    else, val = str2double(val);
    end
end
%%

function out = ftdi_registry(in)
% ports = ftdi_registry(bool); % return FTDI ports, refresh if bool==true 
% key = ftdi_registry(port); % return reg key for port
% 
% The idea is to get FTDI ports (some inactive) and cach their reg keys, so save
% time for latency timer query.
% 'ftdi' root must be right, and PortName/LatencyTimer are under same folder.
persistent ports keys;
if isempty(ports) || (~ischar(in) && in) % refresh port/keys?
    ftdi = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\FTDIBUS';
    [err, str] = system(['reg.exe query ' ftdi ' /v PortName /s']);
    if err, [~, str] = system(['reg.exe query ' ftdi ' /s']); end % winXP
    expr = '\n\s*(HKEY_LOCAL_MACHINE.*?)\r?\n\s*PortName\s+REG_SZ\s+(COM\d+)'; 
    keys = regexp(str, expr, 'tokens');
    keys = [keys{:}];
    ports = keys(2:2:end);
    keys = keys(1:2:end);
    ind = cellfun(@(x)isempty(strfind(x, 'PID_6001')), keys); %#ok
    keys(ind) = []; ports(ind) = [];
end

if ischar(in), out = keys{strcmp(ports, in)}; % ask for key
else, out = ports; % ask for ports
end
%%

function [val, errmsg] = LatencyTimer(port, msecs) %#ok
% Query/change FTDI USB-serial port latency timer. 
%  lat = LatencyTimer(port); % query only 
%  val = LatencyTimer(port, msecs); % query and set to msecs if val>msecs
% 
% Administrator/sudo privilege is normally needed to change the latency timer.
errmsg = '';
warnID = 'LatencyTimer:RestrictedUser';
warnmsg = 'Failed to change latency timer due to insufficient privilege.';
if ispc
    port = strrep(port, '\\.\', '');
    key = ftdi_registry(port); % cach'ed key
    val = regquery(key, 'LatencyTimer');
    if nargin<2, return; end
    msecs = uint8(msecs); % round it and make it within 255
    if val <= msecs, return; end
    
    fid = fopen('temp.reg', 'w'); % create a reg file
    fprintf(fid, 'REGEDIT4\n[%s]\n"LatencyTimer"=dword:%08x\n', key, msecs);
    fclose(fid);
    % change registry, which will fail if not administrator
    [err, txt] = dos('reg.exe import temp.reg 2>&1');
    delete('temp.reg');
    if err
        errmsg = [warnmsg ' ' txt 'You need to start Matlab/Octave by right-clicking'...
            ' its shortcut or executable, and Run as administrator.'];
        if nargout<2, warning(warnID, WrapString(errmsg)); end
    end
elseif ismac
    % port not needed. After the change, all FTDI serial ports may be affected.
    folders = {'/Library/Extensions/FTDIUSBSerialDriver.kext' % for later OS
        '/System/Library/Extensions/FTDIUSBSerialDriver.kext'
        '/System/Library/Extensions/AppleUSBFTDI.kext'
        '/System/Library/Extensions/IOUSBFamily.kext/Contents/PlugIns/AppleUSBFTDI.kext'};
    exists = cellfun(@(f)exist(f, 'file'), folders) > 0;
    ind = find(exists, 1); 
    if isempty(ind)
        emailAuthor('Unknown folder for Info.plist.');
        error('LatencyTimer:plist', 'FTDI/Apple driver not found.');
    end
    folder = folders{ind};
    fname = fullfile(folder, '/Contents/Info.plist');
    str = fileread(fname);
    
    expr = '(?:<key>FTDI2XXB|<key>FT2XXB).*?</dict>'; % block for FTDI2XXB ConfigData
    [i1, i2] = regexp(str, expr, 'start', 'end', 'once');
    expr = '<key>LatencyTimer</key>\s+<integer>(\d+)';
    [val, i3] = regexp(str(i1:i2), expr, 'tokens', 'end', 'once');
    if isempty(i3)
        fprintf(' RTBox USB-serial driver: %s\n', folder);
        error('LatencyTimer:key', 'Failed to detect LatencyTimer key.');
    end
    len = numel(val{1});
    val = str2double(val{1});
    if nargin<2, return; end % query only
    msecs = uint8(msecs);
    if val <= msecs, return; end
    
    tmp = strrep(fname, '/Info.plist', '/tmpfoo');
    fid = fopen(tmp, 'w+'); % test privilege
    if fid<0
        fprintf(' You will be asked for sudo password to change the latency timer.\n');
        fprintf(' Enter to skip the change.\n');
        err = system('sudo -v');
        if err
            errmsg = warnmsg;
            if nargout<2, warning(warnID, WrapString(errmsg)); end
            return;
        end
    else
        fclose(fid);
        delete(tmp);
    end
       
    tmp = '/tmp/tmpfoo';
    i1 = i1+i3-1; % end of LatencyTimer value
    fid = fopen(tmp, 'w');
    fprintf(fid, '%s%i%s', str(1:i1-len), msecs, str(i1+1:end));
    fclose(fid);
    system(['sudo mv -f ' tmp ' ' fname]);
    system(['sudo touch ' folder]);
    system('sudo -k');
    errmsg = 'The change will take effect after you reboot the computer.';
    if nargout<2, warning([mfile ':rebootNeeded'], errmsg); end
else % linux
    fname = '/etc/udev/rules.d/psychtoolbox.rules';
    if exist(fname, 'file')
        str = fileread(fname);
        expr = 'DRIVER=="ftdi_sio",\s*ATTR{latency_timer}="(\d+)"';
        lat = regexp(str, expr, 'tokens', 'once');
        if ~isempty(lat), val = str2double(lat{1}); return; end % suppose good
    end
    warning('Please start Matlab/Octave as sudo and run PsychLinuxConfiguration');
    
    port = strrep(port, '/dev/', '');
    param = ['/sys/bus/usb-serial/devices/' port '/latency_timer'];
    val = str2double(fileread(param));
    if nargin<2, return; end % query only
    msecs = uint8(msecs);
    if val <= msecs, return; end
    if nargout<2, warning(warnID, 'Fail to get LatencyTimer'); end
end
%%