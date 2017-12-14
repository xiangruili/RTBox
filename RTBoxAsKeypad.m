function RTBoxAsKeypad(cmd)
% This sets the RTBox as a keypad, so it can be used in the same way as a
% keyboard. In Matlab, it doesn't make much sense to use the RTBox this way. But
% if one likes to use the RTBox hardware with other software toolkit, this may
% be useful. Matlab has to leave open for this to work.
%
% Note that, as a keypad, the hardware won't have any delay or bias as regular
% keyboard will, but the system delay of key detection will apply to the timing.
%
% RTBoxAsKeypad;
% - Without any input, this will set RTBox as a keypad.
%
% RTBoxAsKeypad stop;
% - Stop the keypad function. The other way is to quit Matlab. Note that
% 'clear all' won't stop it.
%
% RTBoxAsKeypad enableTrigger;
% - By default all triggers are disabled. This will enable the detection of
% trigger. Each trigger will be disabled by itself. So you need to enable it
% after receiving each trigger. The four triggers will be 5, S, L and A for TR,
% sound, light and aux respectively.

% 121001 wrote it (Xiangrui Li)
% 170427 remove dependency on instrument toolbox, but need PTB now
% 171119 Use serIO+timer to replace Matlab serial

persistent tObj;
if nargin<1, cmd = ''; end
if strcmpi(cmd, 'stop') % 'stop' won't complain
    try stop(tObj); end
    try p = tObj.UserData; serIO('Close', p.ser); end
    try serIO('Lock', 0); end %#ok<*TRYNC>
    try delete(tObj); end
    clear tObj;
    munlock;
    return;
end

if isempty(tObj) % initialize
    [port, v] = RTBoxPorts(1);
    if isempty(port)
        error('No RTBox found.');
    elseif numel(port)>1
        fprintf(2, 'Found %g RTBox. The one at %s (v%g) is used.\n', ...
            numel(port), num2str(port{1}), v(1));
    end
    
    port = port{1};
    p.ser = serIO('Open', port);
    serIO('Write', p.ser, 'x'); % simple mode
        
    p.port = port;
    p.VKs = strcat('VK_', {'1' '2' '3' '4' 'S' 'L' '5' 'A'});
    tObj = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.008, ...
        'UserData', p, 'TimerFcn', @timerFcn, 'ObjectVisibility', 'off');
    start(tObj);

    try serIO('Lock', 1); end
    mlock;
end

if strcmpi(cmd, 'EnableTrigger') % returned 'e' will be ignored
    p = tObj.UserData;
    serIO('Write', p.ser, uint8(['e' 61])); % enable all except button release
end

function timerFcn(h, ~)
p = h.UserData;
try
    b = serIO('Read', p.ser); %
catch me % IOPort can't do mexLock, may be closed by clear all
    if isempty(strfind(me.message, 'IOPort')), rethrow(me); end
    p.ser = serIO('Open', p.port);
    serIO('Write', p.ser, 'x'); % simple mode
    serIO('Read', p.ser);
    h.UserData = p;
    return;
end
b = log2(b) + 1; % 1:8
b = b(mod(b,1)==0); % in case of junk data
for i = 1:numel(b)
    java.awt.Robot().keyPress  (java.awt.event.KeyEvent.(p.VKs{b(i)}));
    java.awt.Robot().delay(20);
    java.awt.Robot().keyRelease(java.awt.event.KeyEvent.(p.VKs{b(i)}));
end
