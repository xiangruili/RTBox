function varargout = RTBox (varargin)
% output = RTBox('cmd', para)
% 
% Control USTC Response Time Box. For principle of the hardware, check the
% paper at http://lobes.osu.edu/Journals/BRM10.pdf
%  
% The syntax for RTBox is similar to most functions in Psychtoolbox, i.e., each
% command for RTBox will perform a certain task. To get help for a command, also
% use the similar method to those for Psychtoolbox. For example, to get help for
% RTBox('clear'), you can type either RTBox('clear?') or RTBox clear?
% 
% This is a list of supported commands:
% 
% RTBox('clear');
% RTBox('ButtonNames', {'1' '2' '3' '4'});
% RTBox('TRKey', '5');
% RTBox('ClockRatio' [, seconds]);
% dt = RTBox('ClockDiff');
% [timing, events] = RTBox(timeout);
% RTBox('nEventsRead', nEvents);
% RTBox('UntilTimeout', 0);
% nEvents = RTBox('EventsAvailable');
% [timing, events] = RTBox('BoxSecs', timeout);
% [timing, events] = RTBox('light', timeout);
% [timing, events] = RTBox('sound', timeout);
% RTBox('DebounceInterval', intervalSecs);
% RTBox('enable', {'release' 'light'});
% RTBox('disable', 'release');
% enabledEvents = RTBox('EnableState');
% isDown = RTBox('ButtonDown', buttons);
% timeSent = RTBox('TTL', eventCode);
% RTBox('TTLWidth', widthSecs);
% RTBox('TTLResting', [0 1]);
% timing = RTBox('WaitTR');
% bufferSz = RTBox('BufferSize', newSize);
% thre = RTBox('threshold', newThre);
% RTBox('test');
% RTBox('info');
% RTBox('reset');
% RTBox('close');
% RTBox('fake', 1);
% keys = RTBox('KeyNames');
% [ ... =] RTBox([ ... ,] 'device2');
% RTBox('CloseAll');
% 
% Following are detail description for all above commands.
% 
% RTBox('clear', nSyncTrial);
% 
% - Clear serial buffer, prepare for receiving response. This also synchronizes
% the clocks of computer and device, and enables the detection of trigger event
% if applicable. This is designed to run right before stimulus onset of each
% trial.
% 
% The RTBox events are always buffered. To avoid fake response from previous
% trial or button misclick, always run this before stimulus onset.
% 
% The optional second input nSyncTrial, default 9, is the number of trials to
% synchronize clocks. If you want RTBox('clear') to return quickly, you can set
% it to a smaller number, such as 3. More trials may improve the sync accuracy,
% but it will take longer time. If you want to skip the synchronization, for
% example when you measure RT relative to a trigger, or when you want to return
% 'BoxSecs', you should set nSyncTrial to 0.
% 
% Optionally, this command returns a 3-element row vector: the first is the time
% difference between computer and device clocks; the second is the device time
% when the difference was measured; the third is the upper bound of the
% difference.
% 
% [oldName =] RTBox('ButtonNames',{'left' 'left' 'right' 'right'}); 
%
% - Set/get four button names. The default names are {'1' '2' '3' '4'}. You can
% use any names, except 'sound', 'pulse', 'light', '5', and 'serial', which are
% reserved for other events. If no button names are passed, this will return
% current button names.
% 
% [ratio =] RTBox('ClockRatio', seconds);
% 
% - Measure the clock ratio of computer/RTBox, and save the ratio into the
% device (v1.3+) or a file.  The optional second input specifies how long the
% test will last (default 30 s). If you want to return computer time, it is
% better to do this once before experiment. The program will automatically use
% the test result to correct device time.
% 
% [ratio =] RTBox('ClockDiff', seconds);
% 
% - Return offset between computer/RTBox clock without updating the correction.
% 
% [timing, events] = RTBox('secs', timeout);
% 
% - Return computer time and event names. events are normally button press, but
% can also be button release, sound, light, 5 (tr, v3+), aux (v5+) and serial.
% If you changed button names by RTBox('ButtonNames'), the button-down and up
% events will be your button names. If you enable both button down and up
% events, the name for a button-up event will be its button name plus 'up', such
% as '1up', '2up' etc. timing are for each event, using GetSecs timestamp. If
% there is no event, both output will be empty. If there is one event, the
% returned 'events' will be string array. If there are more than one events, it
% will be a cell string.
% 
% Both input are optional. You can omit 'secs' since it is the default. timeout
% can have two meanings. By default, timeout is the seconds (default 0.1 s) to
% wait from the evocation of the command. Sometimes, you may like to wait until
% a specific time, for example till GetSecs clock reaches TillSecs. Then you can
% use RTBox(TillSecs-GetSecs), but it is better to set the timeout to until
% time, so you can simply use RTBox(TillSecs). You do this by
% RTBox('UntilTimeout', 1). During timeout wait, you can press ESC to abort your
% program. RTBox('secs', 0) will take couple of milliseconds to return after
% several evokes, but this is not guaranteed. If you want to check response
% between two video frames, use RTBox('EventsAvailable') instead.
% 
% This subfunction will return when either time is out, or required events are
% detected. If there are events available in the buffer, this will read back all
% of them. To set the number of events to wait, use RTBox('nEventsRead', n).
%
% [oldValue =] RTBox('nEventsRead', nEvents); 
% 
% - Set the number of events (default 1) to wait during read functions. For
% RTBox('trigger'), this refers to the number of events besides the trigger. If
% you want the read functions to wait for more events, set nEvents accordingly.
% Limitation to v1.4 or earlier: the repeated events due to button bouncing are
% counted as different events.
% 
% [oldBool =] RTBox('UntilTimeout', newBool); 
%
% - By default, read functions don't use until timeout, but use relative
% timeout. For example, RTBox('secs', 2) will wait for 2 seconds from now. In
% your code, you may like to wait till a specific time point. For this purpose,
% you set newBool to 1. Then RTBox('secs', timeout) will wait until the GetSecs
% clock reaches timeout.
% 
% nEvents = RTBox('EventsAvailable'); 
% 
% - Return the number of available events in the buffer. Unlike other read
% functions, the events in the buffer will be untouched after this call. This
% normally takes <1 ms to return, so it is safe to call between video frames.
% Note that the returned nEvents may have a fraction, which normally indicates
% the computer is receiving data.
% 
% [timing, events] = RTBox('BoxSecs', timeout);
% 
% - This is the same as RTBox('secs'), except that the returned time is based on
% the box clock, normally the seconds since the device is powered.
% 
% [timing, events] = RTBox('light', timeout); 
% [timing, events] = RTBox('sound', timeout); 
% [timing, events] = RTBox('TR', timeout); 
% [timing, events] = RTBox('aux', timeout); 
% 
% - These are the same as RTBox('secs'), except that the returned time is
% relative to the provided trigger, 'light', 'sound', 'TR' or ''aux. Since the
% timing is relative to the provided trigger, both the trigger timing, which is
% 0, and the trigger event are omitted in output. Normally the trigger indicates
% the onset of stimulus, so the returned time will be response time. By default,
% this will wait for one event besides the trigger event. The n in
% RTBox('nEventsRead', n) does not include the trigger event. If the trigger
% event is not detected, there will be a warning and both output will be empty,
% no matter whether there are other events.
% 
% [oldValue =] RTBox('DebounceInterval', intervalSecs); 
% 
% - Set/get debounce interval in seconds (default 0.05). RTBox will ignore both
% button down and up events within intervalSecs window after an event of the
% same button. intervalSecs=0 will disable debouncing. The debouncing is
% performed in Matlab code for v1.4 and earlier, and in device firmware for
% later versions. Note that our debounce schemes won't cause any time delay for
% button press.
% 
% The exact interval is normally not important. The only exception is when
% button release event is used. Then one should set shorter interval, e.g. 0.02,
% to avoid the real release event being ignored due to long debounce interval.
% 
% Note that prior to v4.4, RTBox always use default 0.05s when the device is
% opened. Since v4.4, the setting is saved even after the power is lost.
% 
% [enabledEvents =] RTBox('enable', eventsToEanble); 
% [enabledEvents =] RTBox('disable', eventsToDisable);
% 
% - Enable/disable the detection of named events. The events to enable / disable
% can be one of these strings: 'press' 'release' 'sound' 'pulse' 'light' 'TR' or
% 'aux', or cellstr containing any of these strings. The string 'all' is a
% shortcut for all the events. By default, only 'press' is enabled. If you want
% to detect button release time instead of button press time, you need to enable
% 'release', and better to disable 'press'. The optional output returns enabled
% events. If you don't provide any input, it means to query the current enabled
% events. Note that the device will disable a trigger itself after receiving it.
% RTBox('clear') will implicitly enable those triggers after self disabling.
% 
% enabledEvents = RTBox('EnableState');
% 
% - Query the enabled events in the hardware. This may not be consistent with
% those returned by RTBox('enable'), since an external trigger will disable the
% detection of itself in the hardware, while the state in the Matlab code is
% still enabled. RTBox('clear') will enable the detection implicitly. This
% command is mainly for debug purpose.
% 
% isDown = RTBox('ButtonDown', buttons);
%
% - Check button(s) status, 1 for down, 0 for not. If optional buttons is
% provided, only those button state will be reported. For example, if you want
% to wait till button down, you can use
% 
% while ~any(RTBox('ButtonDown')) % wait any button down 
%     WaitSecs('YieldSecs', 0.01); 
% end
% 
% while ~RTBox('ButtonDown', '4') % wait only button 4 down
%     WaitSecs('YieldSecs', 0.01); 
% end
% 
% The button status query will work no matter button-down event is enabled or
% not.
% 
% [timeSent, timeSentUb =] RTBox('TTL', eventCode);
% 
% - Send TTL to DB-25 port (pin 8 is bit 0). The second input is event code
% (default 1), 4-bit (0~15) for version<5, and 8-bit (0~255) for v>=5. It can
% also be equivalent binary string, such as '0011'. The optional output are the
% time the TTL was sent, and its upper bound. The width of TTL is controlled by
% RTBox('TTLWidth') command. TTL function is supported only for v3.0 and later,
% which was designed for EEG event code.
% 
% [oldValue =] RTBox('TTLWidth', widthSecs);
% 
% - Set/get TTL width in seconds. The default width is 0.97e-3. The actual width
% may have some small variation. The supported width by the hardware ranges from
% 0.14e-3 to 35e-3 secs. The infinite width is also supported. Infinite width
% means the TTL will stay until it is changed by next RTBox('TTL') command, such
% as RTBox('TTL', 0).
% 
% If width longer than 35ms is needed, the solution is to use infinite width,
% and turn off the TTL after widthSecs like this:
% 
% RTBox('TTLWidth', inf); % set infinite width early in your code
% RTBox('TTL', eventCode); % send TTL when needed
% WaitSecs(widthSecs); % wait for the width of TTL
% RTBox('TTL', 0); % turn off TTL
% 
% If your code can't afford to wait after sending TTL, timer can be used to turn
% off the TTL. You need to create a single shot timer and set infinite width
% early in your code. The TimerFcn is to turn off the TTL:
% 
% tObj = timer('StartDelay', widthSecs, 'TimerFcn', 'RTBox(''TTL'', 0);');
% RTBox('TTLWidth', inf); % set infinite width
% RTBox('TTL', 0); start(tObj); % exercise the timer once
% 
% When you want to send TTL, do the following to avoid waiting:
% RTBox('TTL', eventCode); start(tObj); % TTL will be off automatically
% 
% Note that prior to v4.4, RTBox always use default width (~1ms) when the device
% is opened. Since v4.4, the setting is saved even after power off.
% 
% In 3<=v<5, the TTL width at DB-25 pins 17~24 is controlled by a potentiometer
% inside the box. In v>=5, the width is also controlled by 'TTLWidth' command.
% 
% [oldValue =] RTBox('TTLResting', newLevel); 
% 
% - Set/get TTL polarity for DB-25 pins 1~8. The default is 0, meaning the TTL
% resting is low. If you set newLevel to nonzero, the resting TTL will be high
% level. If you need different polarity for different pins, let us know.
% 
% Note that prior to v4.4, RTBox always use default level (0) when the device is
% opened. Since v4.4, the setting is saved even after the power is lost.
% 
% In v>=5, newLevel has second value, which is the polarity for pins 17~24.
% 
% [timing =] RTBox('WaitTR');
% 
% - Wait for TR, and optionally return accurate TR time based on computer clock.
% This command will enable TR detection automatically, so you do not need to do
% it in your code. This also detects TR key, 5 for example, so you can simulate
% TR by keyboard press.
% 
% [oldKey =] RTBox('TRKey' [, newKey]); 
% 
% - Set/get TR key. The default is number key '5' on either main keyboard or
% number pad. In case your TR key is not '5', you can set it by this command.
% Then RTBox('WaitTR') will detect the newKey, and you can use newKey to
% simulate TR trigger key. Note that the newKey must by one of keys in
% RTBox('KeyNames'), and must not use button names and other trigger names.
% 
% [bufferSz =] RTBox('BufferSize' [, newSize]);
% 
% - Set/get input buffer size in number of events. The default buffer can hold
% about 585 events, which is enough for most experiments. If you need to buffer
% more events and read all once after long period of time, you can set a new
% larger newSize.
% 
% [oldThre =] RTBox('threshold' [, newThre]); 
% 
% - Set/get threshold for sound and light trigger. There are four levels (1:4)
% of the threshold. Default (1) is the lowest. If, for example, the background
% light is relatively bright and the device detects light trigger at background,
% you can increase the threshold to a higher level. Note that the device will
% save the setting till you change it next time. This function is only available
% for v5+ hardware. The threshold controls the comparator reference voltage. In
% early versions, it is controlled by a potentiometer inside the box, and one
% has to open the box to adjust it.
% 
% RTBox('test');
% 
% - This can be used as a quick command line check for events. It will wait for
% incoming event, and display event name and time when available.
% 
% RTBox('info');
% 
% - Display some parameters of the device if no output is provided. If you want
% to report possible problem for the hardware or the code, please copy and paste
% the screen output by this command.
% 
% RTBox('reset'); 
% 
% - Reset the device clock to zero. This is automatically called when necessary,
% so you rarely need this.
% 
% [isFake =] RTBox('fake', 1);
% 
% - This allows you to test your code without a device connected. If you set
% fake to 1, you code will run without "device not found" error, and you can use
% keyboard to respond. The time will be from KbCheck. To allow your code works
% under fake mode, the button names must be supported key names returned by
% RTBox('KeyNames'). Some commands will be ignored silently at fake mode. It is
% recommended to run this in the Command Window before you test your code. Then
% you can simply 'clear all' to exit fake mode. If you want to use keyboard for
% experiment, you can insert RTBox('fake', 1) in your code before any RTBox
% call. Then if you want to switch to response box, remember to change 1 to 0.
% 
% keys = RTBox('KeyNames');
% 
% - Return all supported key names on your system. The button names at fake mode
% must use supported key names. Most key names are consistent across different
% OS. This won't distinguish the number keys on main keyboard from those on
% number pad.
% 
% RTBox('close');
% - Close one RTBox device.
% 
% RTBox('clear', 'device2'); % clear buffer of device 2
% [timing, events] = RTBox('device2'); % read from device 2
% [ ... =] RTBox( [ ... ,] 'device2');
% 
% - If you need more than one RTBox simultaneously, you must include a device ID
% string as the last input argument for all the RTBox subfunction calls. The
% string must be in format of 'device*', where * must be a single number or
% letter. If 'device*' is not provided, it is equivalent to having 'device1'.
% 
% RTBox('CloseAll');
% - Close all RTBox devices.

% History:
% 03/2008, start to write it. Xiangrui Li
% 07/2008, use event disable feature for firmware v>1.1 according to MK
% 03/2009, TTL functions added for v3.0
% 04/2009, fake mode added 
% 06/2009, fake mode and real mode can work for multi-boxes 
% 06/2009, built-in help available in the same way as PTB functions 
% 06/2009, add EventsAvailable, UntilTimeout and nEventsRead 
% 08/2009, add 'info' and change 'test'
% 09/2009, implement method to set latencyTimer 
% 09/2009, implement portname to open 
% 10/2009, use 'now' instead of GetSecs to save clkRatio for v1.1 
% 11/2009, add HardwareDebounce for v1.4+, except v3.0 
% 11/2009, add TTLresting for v3.1+ to control TTL polarity 
% 11/2009, start to use 1/921600 of clock unit 
% 12/2009, implement EnableState for firmware and Matlab code 
% 01/2010, implement reset for v1.5+
% 01/2010, merge HardwareDebounce into DebounceInterval  
% 02/2010, bug fix for ButtonDown when repeated button names used  
% 06/2010, don't need to reverse TTL bit order for v>3.1  
% 11/2010, take the advantage of WaitSecs('YieldSecs') 
% 02/2011, replace all strmatch with strcmp  
% 03/2011, LatencyTimer updated to work for Windows 7  
% 03/2011, use onCleanup for 2008a and later  
% 04/2011, remove the minimum repeats of 3 for syncClocks  
% 05/2011, make 'sound' command equivalent to 'pulse' 
% 07/2011, bug fix in subFuncHelp  
% 08/2011, remove arbituary debouncing in 'test' 
% 08/2011, allow 8-bit TTL and two TTL resting input for v5.0+ 
% 09/2011, simplify enable method for v4.1+, add aux for v5.0+, could be buggy  
% 09/2011, bug fix for v1.4- in openRTBox, 8-byte info  
% 10/2011, remove dependence on robustfit or regress (thx Craig Arnold) 
% 12/2011, minor change: invert clock ratio byte order
% 01/2012, minor change: make onCleanup independent of matlab version
% 01/2012, change warning log file into current diretory
% 02/2012, remove the fast clockratio correction during opening
% 02/2012, save clockratio to EEPROM v4.3, use MAC address to identify computers
% 03/2012, save TTLwidth, TTLresing and debouncInterval to EEPROM v4.4
% 05/2012, implement BufferSize
% 07/2012, bug fix in enableByte based on report from Imri 
% 07/2012, bug fix for fake mode 'secs': return char for single event,
%            avoid repeated detection by GetChar 
% 07/2012, add 'threshold' subfunction for v5+
% 08/2012, warn user not to use RTBox('start')
% 08/2012, use ListenChar and FlushEvent for RTBox('test') at fake mode
% 09/2012, add instruction to use longer TTL width
% 10/2012, bug fix for b7 scope problem in WaitTR
% 10/2012, add comma between multiple input to avoid warning in late matlab
% 11/2012, for v5: buttonDown uses lower bits, don't get/set8bytes
% 11/2012, minor correction for TTL sending time and upper bound
% 04/2013, disable the warning when all events are disabled
% yymmdd for the rest of history
% 141126 Remove nested func, and make other changes for Octave
% 141130 Add 'TRKey' cmd in main & RTBoxFake. Remove cmd check at beginning
% 141201 Bug fix for closeAll with multiple boxes
% 141204 Exercise timing critical function when opening the device;
% 141205 More useful system info for 'info' command
% 141206 Take care of missing winqueryreg in Octave for LatencyTimer
% 141212 'info' display TTL parameters
% 141213 Remove ListenChar for 'test' at fake mode
% 141215 Bug fix: multi-box info.ID; add boxID for code exercise;
%                 'TRKey' check: avoid error when setting the same key
% 141227 Avoid exercising 'TTL' for v<3
% 150102 linearfit: correct se computation (same as lscov now);
%        Move function line after help (seems necessary for Octave 'help');
%        subFuncHelp: almost re-write, and it should be reliable
% 151104 Avoid error if MACAddress fails
% 160124 implement RTBoxCheckUpdate for convenient update
% 160324 LatencyTimer: bug fix for MAC. Thx Michi.
% 160328 set LatencyTimer to 2 rather than 1 ms.
% 160403 LatencyTimer: check /Library, /System, then Apple's driver.
% 160901 Fix Octave warning for char and onCleanup; ReceiveTimeout=0.1. Thx AW.
% 160905 won't update latency timer if timer<2.
% 160906 Fix timeOut() in firmware: randomly missed 2nd+ bytes. Thx AndreasW
% 160909 use prefdir to save clockratio for old hardware
% 160914 take care of v>1.9 && v<2
% 170315 add cmd 'clockdiff': avoid updating info.sync in syncClocks()
% 170401 show TTLWidth as Inf rather than 0 
% 170418 'info' for output only; remove strkey(); onCleanup is mandated;
%        try reset for box idn (thx AlanF); Add info(id) slot when open succeed;
%        Add trigger RT relative to TR and aux, but not button events;
%        Restore events after ESC exit during waitTR.
% 170426 Remove exercise for TTL and EventsAvailable (not very effective). 
% 170427 Remove portname input in device: hope no one uses it
% 170505 Move open port related part into RTBoxPorts.m, so RTBoxClass shares it.
% 170509 Re-read once in readEEPROM().
% 170626 'buttonNames': bug fix introduced in last update.
% 170716 Add functionSignatures.json file for tab auto-completion.
% 170808 Increase warning thre to 0.005 and 0.003 ms for USBoverload.
% 170913 SyncClocks(): read all once; won't return method3 diff.
%        RTBox('clear') default 9 trials.
% 171005 writeEEPROM: send [3 2] after data to avoid accidental EEPROM write.
% 171008 Replace IOPort with serIO syntax, so work for both serFTDI and IOPort.
% 171009 RTBox('test'): bug fix for boxID.
% 171214 purgeRTBox(): use latency timer to wait.

nIn = nargin; % number of input
if nIn>0 && ischar(varargin{nIn}) && strncmpi('device', varargin{nIn}, 6)
    boxID = varargin{nIn};
    if ~any(boxID=='?'), nIn = nIn-1; end % don't count 'device*'
else
    boxID = 'device1';
end

switch nIn % deal with variable number of input
    case 0, in1 = []; in2 = [];
    case 1 % could be cmd or timeout
        if ischar(varargin{1}), in1 = varargin{1}; in2 = [];
        else, in1 = []; in2 = varargin{1};
        end
    case 2, [in1, in2] = varargin{1:2};
    otherwise, error('Too many input arguments.');
end
if isempty(in1), in1 = 'secs'; end % default command
cmd = lower(in1); % make command and trigger case insensitive
if strcmp(cmd, 'pulse'), cmd = 'sound'; end
if any(cmd=='?'), subFuncHelp(mfilename, in1); return; end % sub function help

persistent info; % struct containing device info
persistent events4enable infoDft; % only to save time
if isempty(infoDft) % no any opened device
    infoDft = struct('ID', boxID, 'portname', '', 'handle', [], 'version', [], ...
        'events', {{'1' '2' '3' '4' '1' '2' '3' '4' 'sound' 'light' '5' 'aux' 'serial'}}, ...
        'enabled', logical([1 0 0 0 0 0]), 'sync', [], 'clkRatio', 1, ...
        'TTLWidth', 0.00097, 'debounceInterval', 0.05, 'latencyTimer', 0.002, ...
        'fake', false, 'nEventsRead', 1, 'untilTimeout', false, ...
        'TTLresting', logical([0 1]), 'clockUnit', 1/115200, 'cleanObj', [], ...
        'MAC', zeros(1,7,'uint8'), 'buffer', 585, 'threshold', 1);
    events4enable = {'press' 'release' 'sound' 'light' 'tr' 'aux'};
    if ~exist('evalc', 'builtin'), more off; eval('evalc=@eval;'); end % Octave
    try evalc('GetSecs;KbCheck;Screen(''computer'')'); end
end

new = isempty(info) || ~any(strncmpi(boxID, {info.ID}, 7));
if new
    id = numel(info) + 1;
else
    id = find(strncmpi(boxID, {info.ID}, 7));
    s = info(id).handle; % serial port handle for current device
    v = info(id).version;
end
if strcmp('fake', cmd)
    if isempty(info), info = infoDft; else, info(id) = infoDft; end % add a slot
    if isempty(in2), varargout{1} = info(id).fake; return; end
    info(id) = RTBoxFake('fake', info(id), in2); 
    if nargout, varargout{1} = info(id).fake; end
    return; 
end
if ~new && info(id).fake % fake mode?
    if nargout==0
        info(id) = RTBoxFake(cmd, info(id), in2);
    else
        [foo, varargout{1:nargout}] = RTBoxFake(cmd, info(id), in2);
        info(id) = foo; % Strange: this solves the slow problem for some MAC
    end
    return; 
end

if new && ~strncmp('close', cmd, 5) % open device unless asked to close
    if isempty(info), bPorts = {};
    else, bPorts = {info.portname}; % ports already open by RTBox
    end

    [port, st] = RTBoxPorts(bPorts); % open first available RTBox
    if isempty(port), RTBoxError('noDevice', st, bPorts); end
    
    s = st.ser; v = st.version;
    if (v>=6 && v<6.1) || (v>=5 && v<5.2) || (v>=4 && v<4.7) || (v>=1 && v<1.91)
        RTBoxWarn('updateFirmware');
    end

    if isempty(info), info = infoDft; else, info(id) = infoDft; end % add a slot
    info(id).ID = boxID;
    info(id).MAC = st.MAC;
    info(id).cleanObj = onCleanup(@()closeRTBox(s));
    
    % Get clockRatio and other para for different versions
    if v>=4.3 || (v>1.9 && v<2)
        if v == 4.3 % ratio in EEPROM
            b8 = get8bytes(s);
            if any(b8(1:3) ~= [248 45 0])
                b8(1:3) = [248 45 0];
                set8bytes(s, b8);
            end
        else % all parameters in EEPROM
            b = readEEPROM(s, 224, 6);
            info(id).TTLWidth = (255-b(1)) / 7200;
            if info(id).TTLWidth==0, info(id).TTLWidth = Inf; end
            info(id).TTLresting = bitget(b(2), 1:2);
            info(id).threshold = bitget(b(2), [4 7]) * (1:2)' + 1;
            info(id).debounceInterval = 256.^(0:3) * b(3:6)' / 921600;
        end
        
        for i = 0:15 % arbituary # of host computers for a box
            b14 = readEEPROM(s, i*14, 14);
            if all(b14(1:6)==255), break; end % EEPROM not written
            if all(info(id).MAC(2:7)==b14(9:14)), break; end % found it
        end
        if i==15, i = 0; end % all slots written
        info(id).MAC(1) = uint8(i*14);
        if ~all(diff(b14(1:6))==0) % just to be safe
            ratio = typecast(uint8(b14(1:8)), 'double');
            if abs(ratio-1)<0.01, info(id).clkRatio = ratio; end
        end
    elseif v>1.1 % but v<=4.2, ratio in RAM
        b8 = get8bytes(s); setB8 = 0;
        if v>4 && any(b8(1:3)~=[248 45 0])
            b8(1:3) = [248 45 0]; setB8 = 1;
        elseif v>1.4 && any(b8(1:3)~=[7 45 0])
            b8(1:3) = [7 45 0]; setB8 = 1; % TTL width, debounceMS & TTLresting
        elseif v<=1.4 && any(b8(1:2)~=[7 16])
            b8(1:2) = [7 16]; setB8 = 1; % default TTL width, scanNum
        end
        if setB8, set8bytes(s, b8); end
        if b8(4)==115 % clock ratio saved
            info(id).clkRatio = 256.^(0:3)*b8(5:8)'/1e10+0.99;
        end
    else % version<=1.1, ratio saved in MAT file
        fname = fullfile(prefdir, 'RTBox_infoSave.mat');
        if exist(fname, 'file')
            S = load(fname); S = S.infoSave;
            i = strcmp(port, {S.portname});
            if any(i)
                S = S(i);
                dt = now*24*3600 - GetSecs;
                tpre = serIO('Write', s, 'Y');
                b7 = serIO('Read', s, 7);
                td = bytes2secs(b7(2:7)', info(id), 1) - S.BoxSecs;
                drift = abs((tpre+dt-S.secs)/td-1);
                if drift<0.01, info(id).clkRatio = S.clkRatio; end % retrieve ratio
            end
        end
    end
    if info(id).clkRatio==1 && ~strcmp(cmd, 'clockratio')
        RTBoxWarn('clockRatioUncorrected');
    end

    % Store para in struct
    info(id).clockUnit = st.clockUnit;
    info(id).version = v;
    info(id).latencyTimer = st.latencyTimer;
    info(id).handle = s; 
    info(id).portname = port;
    info(id).sync = syncClocks(info(id), 9, 1:6); % also enable events
    
    if info(id).sync(2) > 2.5e6 % ~1 month power on
        RTBox('reset', boxID);
    end
    % fprintf(' RTBox opened at %s\n', port);
end

read = {'secs' 'boxsecs' 'sound' 'light' 'tr' 'aux'}; % triggers and read cmd
switch cmd
    case 'eventsavailable'
        varargout{1} = serIO('BytesAvailable', s) / 7;
    case 'ttl' % send TTL
        if isempty(in2), in2 = 1; end % default event code
        if ischar(in2), in2 = bin2dec(in2); end % can be binary string
        if v<3.2
            in2 = dec2bin(in2, 4);
            in2 = bin2dec(in2(4:-1:1)); % reverse bit order
        end
        if v>=5, in2 = [1 in2]; end
        [tpre, tpost] = serIO('Write', s, uint8(in2)); % send

        maxTTL = 255; if v<5, maxTTL = 15; end
        in2 = in2(end);
        if in2<0 || in2>maxTTL || in2~=round(in2)
            RTBoxError('invalidTTL', maxTTL); 
        end
        twin = tpost-tpre;
        tpre = tpre + 8.68e-05 * ((v>=5)+1); % (8+2)/115200
        if nargout, varargout = {tpre twin}; end
        if v<3, RTBoxWarn('notSupported', in1, 3); return; end
        if twin>0.005, RTBoxWarn('USBoverload', twin); end
    case 'start' % send serial trigger to device
        [tpre, tpost] = serIO('Write', s, 'Y');
        twin = tpost - tpre;
        if nargout, varargout = {tpre+8.68e-05 twin}; end
        if twin>0.005, RTBoxWarn('USBoverload', twin); end
    case 'clear'
        if isempty(in2), in2 = 9; end % # of sync
        if in2>0
            if in2 > info(id).buffer
                in2 = info(id).buffer;
                fprintf(2, 'nSyncTrial too big. Reduced to %g\n', in2);
            end
            info(id).sync = syncClocks(info(id), in2, 1:6); % sync clocks
        elseif any(info(id).enabled(3:6))
            enableByte(info(id));
        else, purgeRTBox(info(id));
        end 
        if nargout, varargout{1} = info(id).sync; end
    case 'clockdiff'
        if isempty(in2), in2 = 20; end % # of sync
        varargout{1} = syncClocks(info(id), in2);
    case 'waittr' % wait for scanner TR, for v3.0 or later
        enableByte(info(id), 16); % enable only TR
        tr = info(id).events{11};
        while 1
            if serIO('BytesAvailable', s) >= 7
                if nargout
                    b7 = serIO('Read', s, 7);
                    t = bytes2secs(b7(2:7)', info(id));
                    info(id).sync = syncClocks(info(id), 9); % new sync
                    t = t + info(id).sync(1);
                end
                break;
            end
            [key, t] = ReadKey({tr 'esc'}); % check key press
            if ~isempty(key), break; end
            WaitSecs('YieldSecs', info(id).latencyTimer);
        end
        enableByte(info(id)); % restore events
        if any(strcmp(key, 'esc')), error('User Pressed ESC. Exiting.'); end
        if nargout, varargout{1} = t; end
    case read % 4 trigger events, plus 'secs' 'boxsecs'
        tnow = GetSecs;
        cmdInd = find(strcmp(cmd, read), 1); % which command
        nEventsRead = info(id).nEventsRead;
        if cmdInd>2 % relative to trigger
            nEventsRead = nEventsRead+1; % detect 1 more event
            if ~info(id).enabled(cmdInd)
                RTBoxError('triggerDisabled', events4enable{cmdInd}); 
            end
        end
        if isempty(in2), in2 = 0.1; end % default timeout
        if info(id).untilTimeout, tout = in2;
        else, tout = tnow+in2; % stop time
        end
        varargout = {[], ''}; % return empty if no event detected
        isReading = false;
        nB = serIO('BytesAvailable', s);
        while (tnow<tout && nB<nEventsRead*7 || isReading)
            WaitSecs('YieldSecs', info(id).latencyTimer); % update serial buffer
            nB1 = serIO('BytesAvailable', s);
            isReading = nB1>nB; % wait if reading
            nB = nB1;
            [key, tnow] = ReadKey('esc');
            if ~isempty(key), RTBoxError('escPressed'); end
        end
        nEvent = floor(nB/7);
        if nEvent<nEventsRead, return; end  % return if not enough events
        b7 = serIO('Read', s, nEvent*7);
        b7 = reshape(b7, [7 nEvent]); % each event contains 7 bytes
        timing = [];
        eventcodes = [49:2:55 50:2:56 97 48 57 98 89]; % code for 13 events
        for i = 1:nEvent % extract each event and time
            ind = find(b7(1,i)==eventcodes, 1); % which event
            if isempty(ind)
                RTBoxWarn('invalidEvent', b7(:,i));
                break; % not continue, rest must be messed up
            end
            event{i} = info(id).events{ind}; %#ok event name
            timing(i) = bytes2secs(b7(2:7,i), info(id)); %#ok box time
            eventInd(i) = ind; %#ok for debouncing
        end
        if isempty(timing), return; end

        % software debouncing for <v1.5
        if v<1.5 && info(id).debounceInterval>0 && ...
                numel(unique(eventInd))<numel(eventInd)
            rmvInd = [];
            for i = 1:8 % 8 button down and up events
                ind = find(eventInd==i);
                if numel(ind)<2, continue; end
                bncInd = find(diff(timing(ind))<info(id).debounceInterval);
                rmvInd = [rmvInd ind(bncInd+(i<5))]; %#ok
            end
            event(rmvInd) = []; timing(rmvInd) = [];
        end
        
        if cmdInd==1 % secs: convert into computer time
            if timing(end)-info(id).sync(2) > 9 % sync done too long before?
                sync = info(id).sync(1:2); % remember last sync for interpolation
                info(id).sync = syncClocks(info(id), 9, 1:2); % update sync
                sync(2,:) = info(id).sync(1:2); % append current sync
                tdiff = interp1(sync(:,2), sync(:,1), timing); % linear interpolation
            else, tdiff = info(id).sync(1);
            end
            timing = timing + tdiff; % computer time
        elseif cmdInd>2 % relative to trigger
            ind = find(strcmpi(cmd, event), 1); % trigger index
            if isempty(ind), RTBoxWarn('noTrigger', cmd); return; end
            trigT = timing(ind); % time of trigger event
            event(ind) = []; timing(ind) = []; % omit trigger and its time from output
            if isempty(event), return; end % if only trigger event, return empty
            timing = timing - trigT;   % relative to trigger time
        end
        
        if numel(event)==1, event = event{1}; end % if only 1 event, use string
        varargout = {timing, event};
    case 'purge' % this may be removed in the future. Use RTBox('clear',0)
        if any(info(id).enabled(3:6))
            enableByte(info(id)); % enable trigger if applicable
        else, purgeRTBox(info(id)); % clear buffer
        end
    case 'buttondown'
        enableByte(info(id), 0); % disable all detection
        serIO('Write', s, '?'); % ask button state: '4321'*16 63
        b2 = serIO('Read', s, 2); % ? returns 2 bytes
        enableByte(info(id), 2.^(0:1)*info(id).enabled(1:2)'); % enable buttons
        if numel(b2)~=2 || ~any(b2==63), RTBoxError('notRespond'); end
        b2 = b2(b2~=63); % '?' is 2nd byte for old version 
        if v>=4.7 || (v>1.9 && v<2)
            b2 = bitget(b2, 1:4);
        else
            b2 = bitget(b2, 5:8); % most significant 4 bits are button states
        end
        if nIn<2, in2 = info(id).events(1:4); end % not specified which button
        in2 = cellstr(in2); % convert it to cellstr if it isn't
        for i = 1:numel(in2)
            ind = strcmpi(in2{i}, info(id).events(1:4));
            if ~any(ind), RTBoxError('invalidButtonName', in2{i}); end
            bState(i) = any(b2(ind)); %#ok
        end
        varargout{1} = bState;
    case 'enablestate'
        if v<1.4, RTBoxWarn('notSupported', in1, 1.4); return; end
        for i = 1:4
            serIO('Read', s);
            serIO('Write', s, 'E'); % ask enable state
            b2 = serIO('Read', s, 2); % return 2 bytes
            if numel(b2)==2 && b2(1)=='E', break; end
            if i==4, RTBoxError('notRespond'); end
        end
        b2 = logical(bitget(b2(2), 1:6)); % least significant 6 bits
        varargout{1} = events4enable(b2);
    case 'buttonnames' % set or query button names
        oldNames = info(id).events(1:4);
        if nIn<2, varargout{1} = oldNames; return; end
        if isempty(in2), in2 = {'1' '2' '3' '4'}; end % default
        if numel(in2)~=4 || ~iscellstr(in2)
            RTBoxError('invalidButtonNames'); 
        end
        if ~isempty(intersect(in2, info(id).events(9:end)))
            RTBoxError('conflictName', 'buttonNames', info(id).events(9:end));
        end
        info(id).events(1:8) = [in2 in2];
        if all(info(id).enabled(1:2))
            info(id).events(5:8) = strcat(in2, 'up');
        end
       if nargout, varargout{1} = oldNames; end
    case {'enable' 'disable'} % enable/disable event detection
        if nIn<2 % no event, return current state
            varargout{1} = events4enable(info(id).enabled);
            return;
        end
        isEnable = strcmp(cmd, 'enable');
        if strcmpi(in2, 'all'), in2 = events4enable; end
        in2 = lower(cellstr(in2));
        in2 = strrep(in2, 'pulse', 'sound');
        foo = uint8(2.^(0:5) * info(id).enabled');
        for i = 1:numel(in2)
            ind = find(strcmp(in2{i}, events4enable));
            if isempty(ind), RTBoxError('invalidEnable', events4enable); end
            foo = bitset(foo, ind, isEnable);
            info(id).enabled(ind) = isEnable;
        end
        enableByte(info(id), foo);
        if nargout, varargout{1} = events4enable(info(id).enabled); end
        if all(info(id).enabled(1:2))
            info(id).events(5:8) = strcat(info(id).events(1:4), 'up');
        else
            info(id).events(5:8) = info(id).events(1:4);
        end
    case 'clockratio' % measure clock ratio computer/box
        if nargout, varargout{1} = info(id).clkRatio; return; end
        if isempty(in2), in2 = 30; end % default trials for clock test
        interval = 1; % interval between trials
        nTrial = max(10, round(in2/interval)); % # of trials
        fprintf(' Measuring clock ratio. Trials remaining:%4.f', nTrial);
        enableByte(info(id), 0); % disable all
        i0 = 0; t0 = GetSecs;
        % if more trials, we use first 10 trials to update ratio, then do
        % the rest using the new ratio
        if nTrial >= 20 && info(id).clkRatio==1
            t = zeros(10, 3);
            for i = 1:10
                t(i,:) = syncClocks(info(id), 10); % update, less trial
                WaitTill(t0+interval*i, 'esc', 0); % disable esc exit
                fprintf('\b\b\b\b%4d', nTrial-i);
            end
            info(id).clkRatio = 1 + linearfit(t(:,1:2)); % update ratio
            i0 = i; % start index for next test
        end
        t = zeros(nTrial-i0, 3); t0 = GetSecs;
        for i = 1:nTrial-i0
            t(i,:) = syncClocks(info(id), 40); % update info.sync
            WaitTill(t0+interval*i, 'esc', 0);
            fprintf('\b\b\b\b%4d', nTrial-i-i0);
        end
        fprintf('\n');
        [slope, se] = linearfit(t(:,1:2));
        
        info(id).clkRatio = info(id).clkRatio*(1+slope); % update clock ratio
        if nargout
            varargout{1} = info(id).clkRatio;
        else
            fprintf(' Clock ratio (computer/box): %.8f +- %.8f\n', ...
                info(id).clkRatio, se);
        end

        if se>1e-4, RTBoxWarn('ratioBigSE', se); end
        if abs(slope)>0.01
            info(id).clkRatio = 1; 
            RTBoxError('ratioErr', slope); 
        end
        
        if v >= 4.3 || (v>1.9 && v<2) % store ratio in EEPROM
            if nTrial >= 20
                b8 = typecast(info(id).clkRatio, 'uint8');
                writeEEPROM(s, info(id).MAC(1), [b8 info(id).MAC(2:7)]);
            end
        elseif v>1.1 % store ratio in the device
            b4 = uint32((info(id).clkRatio-0.99)*1e10);
            b4 = typecast(b4, 'uint8');
            b8 = get8bytes(s);
            b8(4:8) = [115; b4(:)]; % b8(4)=='s' to indicate ratio saved
            set8bytes(s, b8);
        else % store into a file for version<=1.1
            fileName = fullfile(prefdir, 'RTBox_infoSave.mat');
            try %#ok<*TRYNC> % load saved info
                i = 1;
                load(fileName);
                i = find(strcmp(info(id).portname, {infoSave.portname})); %#ok
                if isempty(i), i = numel(infoSave)+1; end
            end
            infoSave(i).portname = info(id).portname;
            infoSave(i).clkRatio = info(id).clkRatio;
            dt = now*24*3600-GetSecs;
            tpre = serIO('Write', s, 'Y');
            infoSave(i).secs = dt+tpre;
            b7 = serIO('Read', s, 7);
            infoSave(i).BoxSecs = byte2secs(b7(2:7)', 1);
            save(fileName, 'infoSave');
        end
        info(id).sync = syncClocks(info(id), 9, 1:2); % use new ratio
    case 'ttlwidth'
        if nIn<2, varargout{1} = info(id).TTLWidth; return; end
        if nargout, varargout{1} = info(id).TTLWidth; end
        if v<3, RTBoxWarn('notSupported', in1, 3); return; end
        wUnit = 1/7200; % 0.139e-3 s, width unit, not very accurate
        if isempty(in2), in2 = 0.00097; end
        if isinf(in2), in2 = 0; end
        if (in2<wUnit*0.9 || in2>wUnit*255*1.1) && in2>0
            RTBoxWarn('invalidTTLwidth'); 
        end
        width = double(uint8(in2/wUnit))*wUnit; % real width
        if v >= 4.4
            writeEEPROM(s, 224, uint8(255-width/wUnit));
        else
            b8 = get8bytes(s);
            b8(1) = width/wUnit;
            if v>4, b8(1) = 255-b8(1); end
            set8bytes(s, b8);
        end
        if in2>0 && abs(width-in2)/in2>0.1, RTBoxWarn('widthOffset', width); end
        if width==0, width = inf; end
        info(id).TTLWidth = width;
        purgeRTBox(info(id));
    case 'ttlresting'
        if nIn<2, varargout{1} = info(id).TTLresting; return; end
        if nargout, varargout{1} = info(id).TTLresting; end
        if v<3.1, RTBoxWarn('notSupported', in1, 3.1); return; end
        if isempty(in2), in2 = logical([0 1]); end
        info(id).TTLresting = in2;
        if v >= 4.4
            if numel(in2)>2, in2 = in2(1:2);
            elseif numel(in2)<2, in2(2) = info(id).TTLresting(2);
            end
            b = bitget(info(id).threshold-1, 1:2); % threshold bits
            b = sum(bitset(0, [1 2 4 7], [in2 b]));
            writeEEPROM(s, 225, uint8(b));
        else
            b8 = get8bytes(s);
            b8(3) = in2(1)*240; % '11110000'
            set8bytes(s, b8);
        end
    case 'reset'
        if v<1.4
            RTBoxWarn('notSupported', in1, 1.4); 
            return; 
        end
        if v>4 && v<4.4, b8 = get8bytes(s); end % to restore later
        serIO('Write', s, 'xBS'); % simple mode, boot, bootID
        serIO('Write', s, 'R'); % return, so restart
        serIO('Write', s, 'X'); % advanced mode
        serIO('Read', s, 7+21); % clear buffer
        if v>4 && v<4.4, set8bytes(s, b8); end % restore param
        info(id).sync = syncClocks(info(id), 9, 1:2);
    case 'debounceinterval'
        oldVal = info(id).debounceInterval;
        if nIn<2, varargout{1} = oldVal; return; end
        if isempty(in2), in2 = 0.05; end
        if ~isscalar(in2) || ~isnumeric(in2) || in2<0
            RTBoxError('invalidValue', in1); 
        end
        info(id).debounceInterval = in2;
        if v >= 4.4 || (v>1.9 && v<2)
            b4 = typecast(uint32(in2*921600), 'uint8');
            writeEEPROM(s, 226, b4);
        elseif v >= 1.5
            if in2>0.2833, RTBoxWarn('invalidDebounceInterval'); end
            b8 = get8bytes(s);
            b8(2) = uint8(in2*921600/1024);
            info(id).debounceInterval = b8(2)*1024/921600;
            set8bytes(s, b8);
            purgeRTBox(info(id));
        end
        if nargout, varargout{1} = oldVal; end
    case 'untiltimeout'
        oldVal = info(id).untilTimeout;
        if nIn<2, varargout{1} = oldVal; return; end
        if isempty(in2), in2 = 0; end
        info(id).untilTimeout = in2;
        if nargout, varargout{1} = oldVal; end
    case 'neventsread'
        oldVal = info(id).nEventsRead;
        if nIn<2, varargout{1} = oldVal; return; end
        if isempty(in2), in2 = 1; end
        info(id).nEventsRead = in2;
        if nargout, varargout{1} = oldVal; end
    case 'buffersize'
        oldVal = info(id).buffer;
        if nIn<2, varargout{1} = oldVal; return; end
        if isempty(in2), in2 = 585; end
        info(id).buffer = in2;
        if nargout, varargout{1} = oldVal; end
        bytes = ceil(in2*7/8)*8 *[1 1];
        str = sprintf('InputBufferSize=%i HardwareBufferSizes=%i,4096', bytes);
        verbo = serIO('Verbosity', 0);  
        serIO('Configure', s, str);
        serIO('Verbosity', 0, verbo);
    case 'threshold'
        if nIn<2, varargout{1} = info(id).threshold; return; end
        if nargout, varargout{1} = info(id).threshold; end
        if v<5, RTBoxWarn('notSupported', in1, 5); return; end
        if isempty(in2), in2 = 1; end
        in2 = round(in2);
        in2 = max(min(in2, 4), 1);
        info(id).threshold = in2;
        b = sum(bitset(0, [1 2 4 7], [info(id).TTLresting bitget(in2-1, 1:2)]));
        writeEEPROM(s, 225, uint8(b));
    case 'trkey' % scanner TR trigger key
        oldVal = info(id).events{11};
        if nIn<2, varargout{1} = oldVal; return; end
        if isempty(in2), in2 = '5'; end
        inUse = info(id).events; inUse(11) = []; inUse = unique(inUse);
        if ~ischar(in2), RTBoxError('invalidStr', in1); end
        if any(strcmpi(in2, inUse)), RTBoxError('conflictName', in1, inUse); end
        info(id).events{11} = in2;
        if nargout, varargout{1} = oldVal; end
    case 'test' % quick test for events
        t0 = GetSecs - info(id).sync(1);
        fprintf(' Waiting for events. Press ESC to stop.\n');
        fprintf('%9s%9s-%.4f\n', 'Event', 'secs', t0);
        while isempty(ReadKey('esc'))
            WaitSecs('YieldSecs', 0.02);
            if serIO('BytesAvailable', s)<7, continue; end
            [t, event] = RTBox('boxsecs', 0, boxID);
            event = cellstr(event);
            for i = 1:numel(t)
                fprintf('%9s%12.4f\n', event{i}, t(i)-t0);
            end
        end
    case 'info'
        if nargout, a = info(id); a.cleanObj = []; varargout{1} = a; return; end
        os = '';
        if ispc
            if exist('system_dependent', 'builtin'), os = system_dependent('getos');
            else, [~, os] = system('ver 2>&1');
            end
        elseif ismac
            [~, os] = system('sw_vers -productVersion 2>&1');
        elseif isunix
            [~, os] = system('lsb_release -a 2>&1');
            os = regexp(os, 'Description:\s*(.*?)\n', 'tokens', 'once');
        end
        if iscell(os), os = os{1}; end
        serV = serIO('Version');
        drv = which(serV.module); i = strfind(drv, filesep); drv = drv(i(end)+1:end);
        if exist('OCTAVE_VERSION', 'builtin'), lang = 'Octave'; else, lang = 'Matlab'; end

        fprintf(' Computer: %s (%s)\n', computer, strtrim(os));
        fprintf(' %s: %s\n', lang, version);        
        fprintf(' %s: %s\n', drv, serV.version);
        fprintf(' RTBox.m last updated on 20%s\n', RTBoxCheckUpdate(mfilename));
        fprintf(' Number of events to wait: %g\n', info(id).nEventsRead);
        fprintf(' Use until-timeout for read: %g\n', info(id).untilTimeout);
        fprintf(' boxID(%g): %s, v%.4g\n', id, info(id).ID, v);
        fprintf(' Serial port: %s\n', num2str(info(id).portname)); 
        fprintf(' Serial handle: %g\n', s);
        fprintf(' Latency Timer: %g\n', info(id).latencyTimer);
        fprintf(' Box clock unit: 1/%.0f = %.3g\n', info(id).clockUnit.^[-1 1]);
        fprintf(' Debounce interval: %g\n', info(id).debounceInterval);
        fprintf([' MAC address(%i): ' repmat('%02X-',1,5) '%02X\n'], info(id).MAC); 
        fprintf(' GetSecs/BoxClock unit ratio-1: %.2g\n', info(id).clkRatio-1);
        fprintf(' GetSecs-BoxClock offset: %.5f+%.5f\n', info(id).sync([1 3]));
        fprintf(' Events enabled: %s\n', cell2str(events4enable(info(id).enabled)));
        if v >= 3
            fprintf(' TTL resting level: [%g %g]\n', info(id).TTLresting);
            fprintf(' TTL width: %.2g\n', info(id).TTLWidth);
        end
        if v >= 5
            fprintf(' Light/Sound threshold: %g\n', info(id).threshold);
        end
        fprintf(' Number of events available: %g\n\n', serIO('BytesAvailable',s)/7);
    case 'close' % close one device
        if ~isempty(info), info(id) = []; end % delete a slot, invoke closeRTBox
    case 'closeall' % close all devices
        info = []; % invoke closeRTBox
    case 'keynames'
        varargout{1} = ReadKey('keynames');
    otherwise
       error('Unknown command or trigger: ''%s''.',  in1);
end
% end of main

%% synch clock, and enable event (one serial read only)
function t3 = syncClocks(info, nr, enableInd)
if any(info.enabled), enableByte(info, 0); else, purgeRTBox(info); end % disable all
t = zeros(nr, 3); % tpre, tpost, tbox
for iTry = 1:4
    for i = 1:nr
        WaitSecs((0.7+rand)/1000); % 0.7 for 7-byte transfer: 10*7/115200
        [t(i,1), t(i,2)] = serIO('Write', info.handle, 'Y');
    end
    b7 = serIO('Read', info.handle, 7*nr);
    if numel(b7)==7*nr && all(b7(1:7:end)==89), break; end
    if iTry==4, RTBoxError('notRespond'); end
    purgeRTBox(info);
end
b7 = reshape(b7, [7 nr]);
t(:,3) = bytes2secs(b7(2:7,:), info);

[tdiff, i] = max(t(:,1)-t(:,3)); % the latest tpre is the closest to real write
twin = t(i,2) - t(i,1); % tpost-tpre for the selected sample: upper bound
t3 = [tdiff+8.68e-5 t(i,3) twin]; % tdiff, its tbox and upper bound
if twin>0.005, RTBoxWarn('USBoverload', twin); end
if nargin<3, return; end
foo = 0:5; foo = foo(enableInd); foo = 2.^foo * info.enabled(enableInd)';
enableByte(info, foo); % restore enable

%% send enable byte
function enableByte(info, enByte)
s = info.handle;
v = info.version;
if nargin<2, enByte = 2.^(0:5)*info.enabled'; end
enByte = uint8(enByte);
if v>=4.1 || (v>1.9 && v<2) 
    enByte = [uint8('e') enByte];
    for iTry = 1:4 % try in case of failure
        purgeRTBox(info); % clear buffer
        serIO('Write', s, enByte);
        if serIO('Read', s, 1)==101, break; end % 'e' feedback
        if iTry==4, RTBoxError('notRespond'); end
    end
else
    if v>=1.4
        for iTry = 1:4
            purgeRTBox(info);
            serIO('Write', s, 'E');
            oldByte = serIO('Read', s, 2);
            if numel(oldByte)==2 && oldByte(1)==69, break; end % 'E'
            if iTry==4, RTBoxError('notRespond'); end
        end
        foo = bitxor(enByte, oldByte(2));
    else
        foo = uint8(15); % 4 events
    end
    enableCode = uint8('DUPOF'); % char to enable events, lower case to disable
    for i = 1:5
        if bitget(foo, i)==0, continue; end
        str = enableCode(i);
        if bitget(enByte, i)==0, str = str+32; end % to lower case
        for iTry = 1:4
            purgeRTBox(info); % clear buffer
            serIO('Write', s, str); % send single char
            if serIO('Read', s, 1) == str, break; end % feedback
            if iTry==4, RTBoxError('notRespond'); end
        end
    end
end

%% purge only when idle, prevent from leaving residual in buffer
function purgeRTBox(info)
s = info.handle;
n = serIO('BytesAvailable', s);
tout = GetSecs+1; % if longer than 1s, something is wrong
while 1
    WaitSecs('YieldSecs', info.latencyTimer+0.001); % allow buffer update
    n1 = serIO('BytesAvailable', s);
    if n1==n, break; end % not receiving
    if GetSecs>tout, RTBoxError('notRespond'); end
    n = n1;
end
serIO('Read', s);

%% convert 6-byte b6 into secs according to time unit of box clock.
function secs = bytes2secs(b6, info, ratio)
if nargin<3, ratio = info.clkRatio; end
secs = 256.^(5:-1:0) * b6 * info.clockUnit * ratio;

%% needed only for earlier versions
function b8 = get8bytes(s)
serIO('Read', s);
serIO('Write', s, 's');
b8 = serIO('Read', s, 8);

%% needed only for earlier versions
function set8bytes(s, b8)
serIO('Write', s, 'S');
serIO('Write', s, uint8(b8));
serIO('Read', s, 1);

%% 
function b = readEEPROM(s, addr, nBytes)
serIO('Read', s);
serIO('Write', s, uint8([17 addr nBytes]));
b = serIO('Read', s, nBytes);
if numel(b)<nBytes, b = readEEPROM(s, addr, nBytes); end

%% 
function writeEEPROM(s, addr, bytes)
nBytes = numel(bytes);
serIO('Write', s, uint8(16));
serIO('Write', s, uint8([addr nBytes]));
serIO('Write', s, bytes);
serIO('Write', s, uint8([3 2])); % extra 2 useless bytes, ensuring EEPROM write

%% called by onCleanup
function closeRTBox(s)
try
    evalc('serIO(''Write'', s, ''x'');');
    serIO('Close', s);
end

%% put verbose error message here, to make main code cleaner
function RTBoxError(err, varargin)
switch err
    case 'noUSBserial'
        str = ['No USB-serial ports found. Either device is not connected,' ...
            'or driver is not installed (see User Manual for driver info). ' ...
            'If you like to test your code without RTBox connected, ' ...
            'check RTBox fake? for more information.'];
    case 'noDevice'
        [p, bPorts] = deal(varargin{:});
        if isempty(p.avail) && isempty(p.busy) && isempty(bPorts)
            RTBoxError('noUSBserial');
        end
        str = '';
        if ~isempty(p.avail) % have available ports
            str = sprintf('%s Port(s) available: %s, but failed to get identity.', ...
                str, cell2str(p.avail));
        end
        if ~isempty(p.busy) % have busy ports
            str = sprintf(['%s Port(s) unavailable: %s, probably already in use. ' ...
            'Is any of them the RT device? If yes, try ''clear all'' to close the port.'], ...
            str, cell2str(p.busy));
        end
        if isempty(str), str = 'No available port found.'; end
        if ~isempty(bPorts) % have opened RTBox
            str = sprintf('%s Already opened RT device at %s.', str, cell2str(bPorts));
        end
    case 'conflictName'
        str = sprintf('Valid ''%s'' must not be any of these:\n %s.', ...
            varargin{1}, cell2str(varargin{2}));
    case 'invalidButtonNames'
        str = sprintf('ButtonNames requires a cellstr containing four button names.');
        subfuncHelp('RTBox', 'buttonNames?');
    case 'invalidButtonName'
        str = sprintf('Invalid button name: %s.', varargin{1});
    case 'notRespond'
        str = sprintf('Failed to communicate with device. Try to close and re-connect the device.');
    case 'invalidEnable'
        str = sprintf('Valid events for enable/disable: %s.', cell2str(varargin{1}));
        subfuncHelp('RTBox', 'Enable?');
    case 'triggerDisabled'
        str = sprintf('Trigger is not enabled. You need to enable ''%s''.', varargin{1});
    case 'ratioErr'
        str = sprintf(['The clock ratio difference is too high: %2g%%. Your computer ' ...
            'timing probably has problem.'], abs(varargin{1})*100);
    case 'invalidTTL'
        str = sprintf(['TTL value must be integer from 0 to %g, or ' ...
            'equivalent binary string.'], varargin{1});
        subfuncHelp('RTBox', 'TTL?');
    case 'invalidValue'
        str = sprintf('The value for %s must be a numeric scalar.', varargin{1});
        subfuncHelp('RTBox', [varargin{1} '?']);
    case 'invalidStr'
        str = sprintf('The value for %s must be a string.', varargin{1});
        subfuncHelp('RTBox', [varargin{1} '?']);
    case 'escPressed'
        str = 'User Pressed ESC. Exiting.';
    otherwise, str = err;
end
error(['RTBox:' err], WrapString(str));

%% Show warning message, but code will keep running.
% For record, this may write warning message into file 'RTBoxWarningLog.txt'
function RTBoxWarn(err, varargin)
switch err
    case 'invalidEvent'
        str = sprintf(' %g', varargin{1});
        str = sprintf(['Events not recognized:%s. Please do RTBox(''clear'') ' ...
            'before showing stimulus.\nGetSecs = %.1f'], str, GetSecs);
    case 'noTrigger'
        str = sprintf('Trigger ''%s'' not detected. GetSecs = %.1f', varargin{1}, GetSecs);
    case 'USBoverload'
        str = sprintf(['Possible system overload detected. This may affect ' ...
        'clock sync.\n twin=%.1fms, '], varargin{1}*1000);
        if numel(varargin)>1
            str = sprintf('%stdiff_ub: %.1fms, ', str, varargin{2}*1000); 
        end
        str = sprintf('%sGetSecs=%.1f', str, GetSecs);
    case 'invalidTTLwidth'
        str = sprintf('Supported TTL width is from %.2g to %.2g s .', [1 255]/7200);
    case 'widthOffset'
        str = sprintf('TTL width will be about %.5f s', varargin{1});
    case 'clockRatioUncorrected'
        str = 'Clock ratio has not been corrected. Please run RTBox(''ClockRatio'').';
    case 'ratioBigSE'
        str = sprintf('The slope SE is large: %2g. Try longer time for ClockRatio.',varargin{1});
    case 'notSupported'
        str = sprintf('The command %s is supported only for v%.1f or later.',varargin{1:2});
    case 'invalidDebounceInterval'
        str = 'The debounce interval should be between 0 and 0.2833.';
    case 'updateFirmware'
        str = 'Please run RTBoxCheckUpdate to update RTBox firmware.';
    otherwise
        str = sprintf('%s. GetSecs = %.1f', err, GetSecs);
end
str = WrapString(str);
% warning(['RTBox:' err],str);
fprintf(2,'\n Warning: %s\n', str);
fid = fopen('RTBoxWarningLog.txt', 'a'); 
if fid<0, return; end
fprintf(fid, '%s\n%s\n\n', datestr(now), str); % write warning into log file
fclose(fid);

%% return str from cellstr for printing, also remove port path
function str = cell2str(Cstr)
if isempty(Cstr), str = ''; return; end
str = Cstr;
if ischar(str), str = cellstr(str);
elseif isnumeric(str), str = cellstr(num2str(str));
elseif isnumeric(str{1}), for i=1:numel(str), str{i}=num2str(str{i}); end
end
str = strrep(str, '\\.\', ''); % Windows path for ports
str = strrep(str, '/dev/', '');  % MAC/Linux path for ports
str = sprintf('%s, ' ,str{:}); % convert cell into str1, str2,
str(end+(-1:0)) = ''; % delete last comma and space

%% Compute slope  
function [slope, se] = linearfit(t)
t = bsxfun(@minus, t, mean(t));
[slope, se] = lscov(t(:,2), t(:,1));

%% This calls WaitTill to read keyboard
function [info, varargout] = RTBoxFake(cmd, info, in2)
keys = unique(info.events(1:4));
switch cmd
    case 'eventsavailable'
        varargout{1} = numel(ReadKey(keys));
    case 'buttondown'
        if isempty(in2), in2 = info.events(1:4); end
        key = cellstr(ReadKey(in2));
        down = zeros(1, numel(in2));
        for i = 1:numel(key)
            if isempty(key{i}), break; end
            down(strncmp(key{i}, in2, numel(key{i})))=1;
        end
        varargout{1} = down;
    case {'secs' 'boxsecs'}
        if isempty(in2), in2 = 0.1; end
        if info.untilTimeout, tout = in2;
        else, tout = GetSecs+in2;
        end
        k = {}; t = [];
        nEvents = info.nEventsRead;
        while 1
            [kk, tt] = ReadKey(keys);
            if ~isempty(kk)
                kk = cellstr(kk); n = numel(kk);
                k(end+(1:n)) = kk; t(end+(1:n)) = tt; %#ok
                if numel(k)>=nEvents, break; end
                KbReleaseWait; % avoid detecting the same key
            end
            if tt>tout, break; end
        end
        if isempty(k), t = []; k = '';
        elseif numel(k)==1, k = k{1};
        end
        varargout = {t k};
    case [info.events([9 10 12]) 'tr'] % 4 trigger
        if isempty(in2), in2 = 0.1; end
        t0 = GetSecs; % fake trigger time
        if info.untilTimeout, tout = in2;
        else, tout = t0+in2;
        end
        k = {}; t1 = [];
        nEvents = info.nEventsRead-1;
        if isempty(nEvents), nEvents = 1; end
        while GetSecs<tout
            [kk, tt] = WaitTill(GetSecs+0.01, keys);
            if ~isempty(kk)
                kk = cellstr(kk); n = numel(kk);
                k(end+(1:n)) = kk; t1(end+(1:n)) = tt; %#ok
                if numel(k) >= nEvents, break; end
                KbReleaseWait; % avoid detecting the same key
            end
        end
        if isempty(k), t = []; else, t = t1-t0; end
        varargout = {t k};
    case 'waittr'
        [~, varargout{1}] = WaitTill(info.events{11});
    case {'start' 'ttl'}
        if nargout>1, varargout = {GetSecs 0}; end
    case {'debounceinterval' 'ttlwidth' 'neventsread' 'untiltimeout' 'ttlresting'}
        params = {'debounceInterval' 'TTLWidth' 'nEventsRead' 'untilTimeout' 'TTLresting'};
        ind = strcmpi(cmd,params);
        oldVal = info.(params{ind});
        if isempty(in2), varargout{1} = oldVal; return; end
        info.(params{ind}) = in2;
        if nargout>1, varargout{1} = oldVal; end
    case 'clear'
        if nargout>1, varargout{1} = [0 GetSecs 0 0]; end
    case 'buttonnames'
        varargout{1} = info.events(1:4);
        if isempty(in2), return; end
        if numel(in2)~=4 || ~iscellstr(in2), RTBoxError('invalidButtonNames'); end
        info.events(1:8) = [in2 in2];
    case 'trkey'
        varargout{1} = info.events(11);
        if isempty(in2), return; end
        info.events{11} = in2;
    case {'enable' 'disable' 'enablestate'}
        if isempty(in2) || nargout>1
            varargout{1} = 'press';
        end
    case {'close' 'closeall'}
        clear RTBox;
    case 'fake'
        info.fake = in2;
    case 'keynames'
        varargout{1} = ReadKey('keynames');
    case 'test'
        t0 = GetSecs;
        fprintf(' Waiting for events. Press ESC to stop.\n');
        fprintf('%9s%9s-%.4f\n','Event','secs',t0);
        while 1
            [event, t] = ReadKey({info.events{1:4} 'esc'});
            if isempty(event)
                WaitSecs('YieldSecs', 0.005);
            elseif strcmp(event,'esc')
                break;
            else
                fprintf('%9s%12.4f\n', event, t-t0);
                KbReleaseWait;
            end
        end
    case 'info'
        disp(info)
    otherwise % purge, clockratio etc
        if nargout>1, varargout{1} = 1; end
end
%%