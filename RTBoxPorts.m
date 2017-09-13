function [out, vers] = RTBoxPorts(allPorts)
% [availPorts, vers] = RTBoxPorts(); % return available RTBox ports and vers
% [allPorts, vers] = RTBoxPorts(1); % all RTBox ports and vers (close if needed)
% 
% [port, st] = RTBoxPorts(busyPorts); 
% If the input is a cell, it will be treated as in-use RTBox ports. Then this
% function will open 1st available RTBox port, and return the port name as 1st
% output, and the 2nd output will be a struct containing information like serial
% handle, RTBox version, clock unit, latency timer and host MAC address. In case
% no available RTBox is found, the port will be empty, and the 2nd struct output
% will show available and busy ports.

% 090901 Wrote it (XL)
% 100102 use non-block write to avoid problem for some ports
% 120101 add second output
% 120701 Return from bootloader or RTBoxADC if needed
% 170426 RTBox.m, RTBoxClass.m etc start to call this to open port
% 170502 Include MACAddress() and LatencyTimer() here for convenience
% 170508 filters FTDI ports for all OS.
% 170523 Linux LatencyTimer: start to use psychtoolbox.rules (Thx Mario K).
% 170608 ftdi_vcp_win(): check FTDI PID, cach active VCP for ftdi_registry().
% 170610 ftdi_vcp_mac(): bug fix for ports{1} (worked only for 1 port).

if nargin<1, allPorts = false; end
toOpen = ischar(allPorts) || iscellstr(allPorts); % to open first avail port 

verbo = IOPort('Verbosity', 0); % shut up screen output and error
cln = onCleanup(@() IOPort('Verbosity', verbo));

if ~toOpen && logical(allPorts) % ask all ports, so close opened ones
    try RTBox('CloseAll'); end
    try RTBoxClass.instances('closeAll'); end
    try RTBoxSimple('close'); end
end

if     ispc,   ports = ftdi_vcp_win();
elseif ismac,  ports = ftdi_vcp_mac();
elseif isunix, ports = ftdi_vcp_lnx();
else, error('Unsupported system: %s.', computer);
end

out = {}; vers = [];
cfgStr = 'BaudRate=115200 ReceiveTimeout=0.2 PollLatency=0.0001';
rec = struct('avail', '', 'busy', ''); % for error message only

for i = 1:numel(ports)
    port = ports{i};
    if any(strcmp(port, allPorts)), continue; end % avoid multi-open in unix
    s = IOPort('OpenSerialPort', port, cfgStr);
    if s<0, rec.busy{end+1} = port; continue; end
    
    idn = RTBox_idn(s);
    if strncmp(idn, '?', 1) % maybe in boot/RTBoxADC
        IOPort('Write', s, 'R'); % return to application
        WaitSecs('YieldSecs', 0.1); drawnow;
        idn = RTBox_idn(s);
    end
    if numel(idn) < 21 % re-open to fix rare ID failure
        IOPort('Close', s); WaitSecs('YieldSecs', 0.01);
        s = IOPort('OpenSerialPort', port, cfgStr);
        idn = RTBox_idn(s);
        if numel(idn)<21, idn = RTBox_idn(s); end % try one more time
    end
    if numel(idn)==21 && strncmp(idn, 'USTCRTBOX', 9)
        v = str2double(idn(19:21));
        if v>100, v = v/100; end % v510, rather than v5.1
        if toOpen
            out = port; break; % leave it open
        else
            out{end+1} = port; vers(end+1) = v; %#ok<*AGROW>
        end
    else
        rec.avail{end+1} = port; % avail but not RTBox
    end
    IOPort('Close', s); % close it
end

if isempty(out), vers = rec; return; end % no RTBox found
if ~toOpen, return; end

% The rest is for RTBox.m, RTBoxClass.m etc to set up serial port
try [oldVal, err] = LatencyTimer(port, 2); lat = min(2, oldVal);
catch me, oldVal = 16; err = me.message; lat = 16; % in case of error
end
if ~isempty(err) % error, failed to change, or change not effective
    if ~ismac && oldVal>2 % no warning for mac until we have a solution
        warning('LatencyTimer:Fail', ['%s\nThis simply means failure to speed ' ...
            'up USB-serial port reading. It won''t affect RTBox function.'], err);
    end
    lat = oldVal;
end
if oldVal>lat % close/re-open to make change effect
    IOPort('Close', s);
    s = IOPort('OpenSerialPort', port, cfgStr);
end

vers = struct('ser', s, 'version', v, 'clockUnit', 1/str2double(idn(11:16)));
vers.latencyTimer = lat/1000;
vers.MAC = [0 MACAddress];
%%

function idn = RTBox_idn(s) % return RTBox idn str
IOPort('Purge', s); % clear buffer
IOPort('Write', s, 'X'); % blocking write is fine with FTDI ports
idn = char(IOPort('Read', s, 1, 21)); % USTCRTBOX,921600,v6.1
%%

function ports = ftdi_vcp_lnx()
% Return FTDI serial ports under Linux.
ports = dir('/dev/ttyUSB*');
ports = {ports.name};
for i = numel(ports):-1:1
    ports{i} = ['/dev/' ports{i}];
    [~, str] = system(['udevadm info -a -n ' ports{i}]);
    ib = [regexp(str, '\n\s*looking at') numel(str)];
    no0403 = true;
    for j = regexp(str, '{idProduct}=+"6001"') % likely only 1 block has '6001'
        i1 = ib(find(ib<j, 1, 'last'));
        i2 = ib(find(ib>j, 1));
        iv = regexp(str(i1:i2), '{idVendor}=+"0403"', 'once');
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
[~, str] = system('ioreg -x -l -p IOUSB'); % much faster than system_profiler
ib = [regexp(str, '\+-o') numel(str)]; % tree start
IDs = {}; % location IDs for FTDI USB-serial
expr = '"locationID"\s*=\s*0x([0-9a-fA-F]+)'; % 3d100000
for i = regexp(str, '"idProduct"\s*=\s*0x6001')
    i1 = ib(find(ib<i, 1, 'last'));
    i2 = ib(find(ib>i, 1));
    iv = regexp(str(i1:i2), '"idVendor"\s*=\s*0x0?403', 'once');
    if ~isempty(iv)
        a = regexp(str(i1:i2), expr, 'tokens', 'once');
        IDs{end+1} = a{1};
    end
end

ports = dir('/dev/cu.usbserial*');
ports = {ports.name};
for i = numel(ports):-1:1
    p = regexp(ports{i}, '(?<=-).*', 'match', 'once'); % 0000103D or 145
    ports{i} = ['/dev/' ports{i}];
    n = numel(p); % 8 for FTDI driver, likely 3 for Apple driver
    if n<3 || n>8, emailAuthor(sprintf('%s ', IDs{:}, ports{:})); end
    % if numel(ports)==1, return; end % remove this in the future
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
    for i = 1:numel(ports), ports{i} = ports{i}{1}; end
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
persistent ports keys;
if isempty(ports) || (~ischar(in) && in) % refresh port/keys?
    ftdi = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\FTDIBUS';
%     [~, str] = system(['reg.exe query ' ftdi ' /v PortName /s']);
%     keys = regexp(str, 'HKEY_LOCAL_MACHINE\\.*?(?=\n)', 'match');
%     ports = regexp(str, '(?<=REG_SZ\s+)COM\d+(?=\n)', 'match');
%     no6001 = cellfun(@isempty, strfind(keys, 'PID_6001'));
%     keys(no6001) = []; ports(no6001) = [];
    
    [~, str] = system(['reg.exe query ' ftdi]);
    str = strrep(str, char([13 10]), char(10)); % Octave has \r\n, Matlab \n
    str = regexp(strtrim(str), '\n', 'split');
    ports = {}; keys = {};
    for i = 1:numel(str)
        if isempty(strfind(str{i}, 'PID_6001')), continue; end
        key = [str{i} '\0000\Device Parameters']; % hope format stays
        p = regquery(key, 'PortName');
        if ~isempty(p), ports{end+1} = p; keys{end+1} = key; end
    end
end

if ischar(in), out = keys{strcmp(ports, in)}; % ask for key
else, out = ports; % ask for ports
end
%%

function mac = MACAddress()
% Return computer MAC address in uint8 of length 6. If all attemps fail, there
% will be a warning, and last 6 char of host name will be returned for RTBox.
% sprintf('%02X-%02X-%02X-%02X-%02X-%02X', MACAddress) % '-' separated hex
mac = zeros(1, 6, 'uint8');
try
    a = sscanf(MACAddress_mex(), '%2x%*c', 6);
    if numel(a)==6 && ~all(a==0), mac(:) = a; return; end
end
try %#ok<*TRYNC> OSX and Linux will return from this block
    a = Screen('computer');
    hex = a.MACAddress;
    a = sscanf(hex, '%2x%*c', 6);
    if numel(a)==6 && ~all(a==0), mac(:) = a; return; end
end

try % java approach faster than getmac, mainly for Windows
    ni = java.net.NetworkInterface.getNetworkInterfaces;
    while ni.hasMoreElements
        a = ni.nextElement.getHardwareAddress;
        if numel(a)==6 && ~all(a==0)
            mac(:) = typecast(a, 'uint8'); % from int8
            return; % 1st is likely ethernet adaptor
        end
    end
end

try % system command is slow
    if ispc
        [err, str] = system('getmac.exe 2>&1');
        expr = '(?<=\s)([0-9A-F]{2}-){5}[0-9A-F]{2}(?=\s)'; % separator -
    else
        [err, str] = system('ifconfig 2>&1');
        expr = '(?<=\s)([0-9a-f]{2}:){5}[0-9a-f]{2}(?=\s)'; % separator :
    end
    if err, error(str); end % unlikely to happen
    hex = regexp(str, expr, 'match', 'once');
    a = sscanf(hex, '%2x%*c', 6);
    if numel(a)==6, mac(:) = a; return; end
end

warning('MACAddress:Fail', 'Using last 6 char of hostname as MACAddresss');
[~, nam] = system('hostname'); nam = strtrim(nam);
if numel(nam)<6, nam = ['myhost' nam]; end
mac(:) = nam(end+(-5:0));
%%

function [val, errmsg] = LatencyTimer(port, msecs)
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
    [err, txt] = system('reg.exe import temp.reg 2>&1');
    delete('temp.reg');
    if err
        errmsg = [warnmsg ' ' txt 'You need to start Matlab/Octave by right-clicking'...
            ' its shortcut or executable, and Run as administrator.'];
        if nargout<2, warning(warnID, WrapString(errmsg)); end
    end
elseif ismac
    % port not needed. After the change, all FTDI serial ports may be affected.
    useFTDI = true; % use FTDI driver
    folder = '/Library/Extensions/FTDIUSBSerialDriver.kext'; % for later OS
    fname = fullfile(folder, '/Contents/Info.plist');
    if ~exist(fname, 'file')
        folder = '/System/Library/Extensions/FTDIUSBSerialDriver.kext';
        fname = fullfile(folder, '/Contents/Info.plist');
    end
    if ~exist(fname, 'file')
        useFTDI = false; % use driver from Apple: different keys
        folder = '/System/Library/Extensions/AppleUSBFTDI.kext';
        fname = fullfile(folder, '/Contents/Info.plist');
    end
    if ~exist(fname, 'file')
        useFTDI = false; % use driver from Apple: different keys
        folder = '/System/Library/Extensions/IOUSBFamily.kext/Contents/PlugIns/AppleUSBFTDI.kext';
        fname = fullfile(folder, '/Contents/Info.plist');
    end
    if ~exist(fname, 'file')
         error('LatencyTimer:plist', 'Info.plist not found.');
    end
    
    fid = fopen(fname);
    str = fread(fid, '*char')';
    fclose(fid);
    
    if useFTDI
        ind = regexp(str, '<key>FTDI2XXB', 'once');
        if isempty(ind), ind = regexp(str, '<key>FT2XXB', 'once'); end
    else
        ind = regexp(str, '<key>AppleUSBEFTDI-6001', 'once');
    end
    if isempty(ind)
        error('LatencyTimer:key', 'Failed to detect FTDI key.');
    end
    i2 = regexp(str(ind:end), '</dict>', 'once') + ind; % end of ConfigData
    expr = '<key>LatencyTimer</key>\s+<integer>\d{1,3}</integer>';
    [mat, i0, i1] = regexp(str(ind:i2), expr, 'match', 'start', 'end', 'once');
    if isempty(i0) % likely AppleUSBFTDI drive: seems not accept LatencyTimer
        fprintf(2, '%s\n', fname);
        error('LatencyTimer:key', 'Failed to detect LatencyTimer key.');
    end
    valStr = regexp(mat, '\d{1,3}(?=</integer>)', 'match', 'once');
    val = str2double(valStr);
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
    
    i0 = i0+ind-1; i1 = i1+ind-1; % index of mat in str, including
    mat = strrep(mat, [valStr '</integer>'], [num2str(msecs) '</integer>']);
   
    tmp = '/tmp/tmpfoo';
    fid = fopen(tmp, 'w+');
    fprintf(fid, '%s', str(1:i0-1)); % before mat
    fprintf(fid, '%s', mat); % modified mat
    fprintf(fid, '%s', str(i1+1:end)); % after mat
    fclose(fid);
    system(['sudo mv -f ' tmp ' ' fname]);
    system(['sudo touch ' folder]);
    system('sudo -k');
    errmsg = 'The change will take effect after you reboot the computer.';
    if nargout<2, warning([mfile ':rebootNeeded'], errmsg); end
else % linux
    fname = '/etc/udev/rules.d/psychtoolbox.rules';
    if exist(fname, 'file')
        fid = fopen(fname); str = fread(fid, '*char')'; fclose(fid);
        expr = 'DRIVER=="ftdi_sio",\s*ATTR{latency_timer}="(\d+)"';
        lat = regexp(str, expr, 'tokens', 'once');
        if ~isempty(lat), val = str2double(lat{1}); return; end % suppose good
    end
    warning('Please start Matlab/Octave as sudo and run PsychLinuxConfiguration');
    
    port = strrep(port, '/dev/', '');
    param = ['/sys/bus/usb-serial/devices/' port '/latency_timer'];
    [~, lat] = system(['cat ' param]); % query
    val = str2double(lat);
    if nargin<2, return; end % query only
    msecs = uint8(msecs);
    if val <= msecs, return; end
    if nargout<2, warning(warnID, 'Fail to get LatencyTimer'); end
end
%%

% function [err, out] = system_file(cmd)
% % The same as [err, out] = system(cmd), but better performance with large out.
% persistent fname deleteFile
% if isempty(deleteFile)
%     fname = [tempdir 'temp_output_junk.txt'];
%     deleteFile = onCleanup(@() delete(fname)); % delete only when cleared
% end
% err = system([cmd ' > "' fname '"']);
% fid = fopen(fname);
% out = fread(fid, '*char')';
% fclose(fid);
%%
