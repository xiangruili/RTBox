function RTBoxFirmwareUpdate(hexFileName)
% RTBoxFirmwareUpdate (hexFileName)
%
% Update firmware for RTBox v1.4 and later.
% The optional input is the file name of firmware hex. If you omit it, you
% will be asked to browse.

% History (yymmdd):
% 091201 wrote it (Xiangrui Li)
% 100101 remove dependence on avrdude (xl)
% 110801 check hardware version compatibility (xl)
% 120301 improve hex parser so it works with hex file with broken lines
% 120601 correct version check with floor instead of round.
% 120701 simplify and cosmetic.
% 141123 Make it work for Octave.
% 150105 Find version info in hex, rather than file name;
%        Remove % progress since it has problem with some nojvm mode.
% 160906 Bug fix cleanup() input when failing to verify.
% 171012 Use serIO wrapper.

% intel HEX format:
% :10010000214601360121470136007EFE09D2190140
% Start code(:), Byte count(1 byte), Address(2 bytes), Record type(1 byte),
%   Data (bytes determined by Byte count), Checksum(1 byte).
% Record type (00, data record; 01, End Of File record)

if nargin<1 || isempty(hexFileName)
    [hexFileName, pname] = uigetfile('RTBOX*.hex', 'Select HEX file');
    if ~ischar(hexFileName), return; end % user cancelled
    hexFileName = fullfile(pname, hexFileName);
elseif ~exist(hexFileName,'file') % check hex file
    error(' Provided HEX file not exists.');
end

more off;
fprintf(' Checking HEX file ...');
[b, startAddr] = read_intel_hex(hexFileName);
fprintf(' Done\n');
ch = char(b);
nByte = numel(b);
bytePL = 16; % bytes of each write
nWrite = ceil(nByte/bytePL); % # of writes
b(nByte+1:nWrite*bytePL) = 255;
b = reshape(b, bytePL, nWrite)';

ind = strfind(ch, 'USTCRTBOX');
v = str2double(ch(ind+(18:20)));
if v>10, v = v/100; end

% check connected RTBox
[port, vv] = RTBoxPorts(1); % get all ports for boxes 
if isempty(port)
    err = sprintf(['No working RTBox found. If your box is connected, ' ...
        'please unplug it now. If not, plug it while pressing down buttons 1 and 2.\n\n']);
    fprintf(WrapString(err));
    ports = FTDIPorts(); nports = numel(ports); % find FTDI ports
    while 1
        portsNew = FTDIPorts();
        if numel(portsNew) < nports % unplugged
            fprintf(' Detected that a port has been unplugged.\n');
            fprintf(' Now plug it while pressing down buttons 1 and 2.\n');
            ports = portsNew; nports = numel(ports);
        elseif numel(portsNew)>nports % plugged
            fprintf(' Plugged port detected.\n');
            break;
        end
        KbEventClass.esc_exit();
    end
    if isnumeric(portsNew{1})
        portsNew = [portsNew{:}]; ports = [ports{:}];
        port = setdiff(portsNew, ports); % new-plugged port
    else
        port = setdiff(portsNew, ports); port = port{1};
    end
    pause(0.5);
    s = serIO('Open', port);
    serIO('Write', s, 'S'); % ask 'AVRBOOT'
elseif numel(port)==1 % one RTBox
    s = serIO('Open', port{1});
    if ~isnan(v) % check compatibility if we have version info
        if floor(v) ~= floor(vv) % major version different
            q = questdlg(sprintf(['Hardware and firmware may not be compatible.\n' ...
                'Are you sure you want to continue?']),...
                'Version Warning', 'Yes', 'No', 'No');
            if strcmp(q, 'No'), cleanup(s); return; end
        end
    end
    serIO('Write', s, 'x'); % make sure we enter simple mode
    serIO('Write', s, 'B'); % jump to boot loader from simple mode
    serIO('Write', s, 'S'); % enter boot mode and ask 'AVRBOOT'
else % more than one boxes connected
    error(' More than one RTBoxes found. Please plug only one.');
end
idn = serIO('Read', s, 7); % read boot id
if ~strcmp(char(idn), 'AVRBOOT')
    cleanup(s, 'Failed to enter boot loader.');
end
serIO('Configure', s, 'ReceiveTimeout=1'); % erase takes longer

% now we are in AVRBOOT, ready to upload firmware HEX
serIO('Write', s, 'Tt'); % set device type
checkerr(s, 'set device type');

fprintf(' Erasing flash ...');
serIO('Write', s, 'e'); % erase
checkerr(s, 'erase flash');
fprintf(' Done\n');

serIO('Write', s, uint8(['A' startAddr])); % normally 0x0000
checkerr(s, 'set address');

fprintf(' Writing flash ...');
cmd = uint8(['B' 0 bytePL 'F']); % cmd high/low bytes, Flash
for i = 1:nWrite
    serIO('Write', s, cmd);
    serIO('Write', s, b(i,:)); % write a page
    checkerr(s, sprintf('write flash page %g', i));
end
fprintf(' Done\n');

serIO('Write', s, uint8(['A' startAddr])); % set start address to verify
checkerr(s, 'set address');

fprintf(' Verifying flash ...');
cmd = uint8(['g' 0 bytePL 'F']); % cmd high/low bytes, Flash
for i = 1:nWrite
    serIO('Write', s, cmd);
    ln = serIO('Read', s, bytePL); % read a page back
    if numel(ln)<bytePL || ~isequal(ln, b(i,:))
        cleanup(s, sprintf('Failed to verify page %g. Please try again.',i));
    end
end
fprintf(' Done.\n');
cleanup(s);

function cleanup(s, err)
serIO('Write', s, 'R'); % jump to application
serIO('Close', s);
if nargin>1, error(err); end

% check returned '\r', close port in case of error
function checkerr(s, str)
back = serIO('Read', s, 1); % read '\r'
if isempty(back) || back~=13
    cleanup(s, sprintf('\n Failed to %s.', str));
end

%% Read intel hex file, return bytes and startAddress.
% If address are not continuous, 0xff will fill the gap.
% intel HEX format:
% :10010000214601360121470136007EFE09D2190140
% Start code(:), Byte count(1 byte), Address(2 bytes), Record type(1 byte),
%   Data (bytes determined by Byte count), Checksum(1 byte).
% Record type (00, data record; 01, End Of File record)
function [bytes, startAddr] = read_intel_hex(hexFileName)
hex = regexp(fileread(hexFileName), ':([0-9A-F]{1,})\s+', 'tokens');
nLine = length(hex);

for i = 1:nLine
    ln = sscanf(hex{i}{1}, '%2x'); % get a line in hex
    if ln(4)==0, break; end % 0 mean first data line
end
startAddr = ln(2:3)'; % normally 0 for application
i0 = ln(2)*256 + ln(3); % normally 0 for application

for i = nLine : -1 : 1
    ln = sscanf(hex{i}{1}, '%2x'); % get a line in hex
    if ln(4)==0, break; end % last data line
end
nByte = ln(1) + ln(2)*256 + ln(3) - i0; % max bytes of hex file

bytes = repmat(uint8(255), 1, nByte); % initialize with 0xff
for i = 1:nLine
    ln = sscanf(hex{i}{1}, '%2x'); % get a line in hex
    if ln(4), continue; end % not data line, skip
    chksum = mod(-sum(ln(1:end-1)), 256);
    if chksum ~= ln(end)
        error('Checksum error at line %g. HEX file corrupted.', i);
    end
    i1 = ln(2)*256 + ln(3) - i0; % start index for this line
    bytes(i1 + (1:ln(1))) = ln(5:end-1); % data
end
