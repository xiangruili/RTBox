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
% 170918 ftdi_registry(): now only reply on stable ftdi rootkey. 
% 171011 Use serIO wrapper, and extract FTIDPorts(). 

if nargin<1, allPorts = false; end
toOpen = ischar(allPorts) || iscell(allPorts); % to open first avail port 

if ~toOpen && logical(allPorts) % ask all ports, so close opened ones
    try RTBox('CloseAll'); end
    try RTBoxClass.instances('closeAll'); end
end

out = {}; vers = [];
rec = struct('avail', '', 'busy', ''); % for error message only
ports = FTDIPorts();
if iscell(allPorts) % avoid multi-open in unix
    rec.busy = allPorts;
    for i = 1:numel(allPorts)
        if ischar(allPorts{i}), ind = strcmp(allPorts{i}, ports);
        else, ind = cellfun(@(c) eq(c,allPorts{i}), ports);
        end
        ports(ind) = [];
    end
end
nPorts = numel(ports);
if nPorts<1, vers = rec; return; end % no RTBox found

for i = 1:nPorts
    port = ports{i};
    [s, ~] = serIO('Open', port);
    if s<0, rec.busy{end+1} = port; continue; end

    idn = RTBox_idn(s);
    if strncmp(idn, '?', 1) % maybe in boot/RTBoxADC
        serIO('Write', s, 'R'); % return to application
        WaitSecs('YieldSecs', 0.1); drawnow;
        idn = RTBox_idn(s);
    end
    if numel(idn) < 21 % re-open to fix rare ID failure
        serIO('Close', s); WaitSecs('YieldSecs', 0.01);
        s = serIO('Open', port);
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
    serIO('Close', s); % close it
end

if isempty(out), vers = rec; return; end % no RTBox found
if ~toOpen, return; end

if serIO('use_serFTDI')
    lat = 0.002;
else
    try [oldVal, err] = FTDIPorts('LatencyTimer', port, 2); lat = min(2, oldVal);
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
    lat = lat / 1000;
end
vers = struct('ser', s, 'version', v, 'clockUnit', 1/str2double(idn(11:16)), ...
    'latencyTimer', lat, 'MAC', [0 MACAddress]);
return;
%%

function idn = RTBox_idn(s) % return RTBox idn str
serIO('Read', s); % clear buffer
serIO('Write', s, 'X'); % blocking write is fine with FTDI ports
idn = char(serIO('Read', s, 21)); % USTCRTBOX,921600,v6.1
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

try % system command is slow
    if ispc
        fname = [tempdir 'tempmac.txt'];
        [err, ~] = system(['ipconfig.exe /all > ' fname]); % faster with file
        str = fileread(fname); delete(fname);
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

warning('MACAddress:Fail', 'Using last 6 char of hostname as MACAddresss');
[~, nam] = system('hostname'); nam = strtrim(nam);
if numel(nam)<6, nam = ['myhost' nam]; end
mac(:) = nam(end+(-5:0));
%%
