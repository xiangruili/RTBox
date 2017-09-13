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

persistent s rob VKs tObj btn;
if nargin<1, cmd = ''; end
if strcmpi(cmd, 'stop')
    delete(s);
    delete(tObj);
    clear s tObj;
    munlock;
    return;
end

if isempty(rob)
    import java.awt.*;
    import java.awt.event.*;
    rob = Robot; % create a robot
    VKs = strcat('VK_', {'1' '2' '3' '4' 'S' 'L' '5' 'A'});
end

% this is called by timerFcn, not by users
if strcmp(cmd, 'release')
    for i = 1:numel(btn)
        rob.keyRelease(KeyEvent.(VKs{btn(i)}));
    end
    btn = [];
    return;
end

if isempty(s)
    [port, v] = RTBoxPorts(1);
    port = strrep(port, '\\.\', '');
    if isempty(port)
        error('No RTBox found.');
    elseif numel(port)>1
        fprintf(2, 'Found %g RTBox. The one at %s (v%g) is used.\n', ...
            numel(port), port{1}, v(1));
    end
    
    s = serial(port{1}, 'BaudRate', 115200, 'Timeout', 0.3);
    s.BytesAvailableFcn = 'RTBoxAsKeypad';
    s.BytesAvailableFcnCount = 1; % one byte event at simple mode
    s.BytesAvailableFcnMode = 'byte'; % byte, not terminator
    fopen(s);
    fprintf(s, 'x'); % simple mode
    
    % timer to control keypress duration. Needed for KbCheck detection. The
    % exact length is not critical, since key doesn't repeat.
    tObj = timer('StartDelay', 0.1); % single shot by default
    tObj.ObjectVisibility = 'off'; % prevent from deleting by other program
    tObj.TimerFcn = 'RTBoxAsKeypad(''release'');'; % VK keyRelease
    
    mlock;
end

if strcmpi(cmd, 'EnableTrigger')
    fprintf(s, ['e' 61]); % enable all except button release
    return; % returned 'e' will be ignored
end

n = s.BytesAvailable;
if n<1, return; end
b = fread(s, n); %
b = log2(b) + 1; % 1:8
b = b(mod(b,1)==0); % in case of junk data
n = numel(b);
if n<1, return; end
for i = 1:n
    if any(b(i)==btn), continue; end
    rob.keyPress(KeyEvent.(VKs{b(i)})); % keyPress
    btn = [btn; b(i)]; %#ok in case previous keys were not released
end
if strcmp(tObj.Running, 'off'), start(tObj); end
% start timer to release key, so we won't block matlab
