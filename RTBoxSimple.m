function varargout = RTBoxSimple (varargin)
% RTBoxSimple: use Response Time Box in simple mode.
% 
% The advantage of RTBoxSimple over RTBox is that, it runs faster, so it is
% safer to read response between video frames. But it won't return the time
% based on RTBox clock, so the timing accuracy is not as good as advanced
% mode. 
%  
% RTBoxSimple('clear');
% - Clear serial buffer, and enable trigger detection if applicable. This
% is normally needed before each trial.
% 
% [events t]= RTBoxSimple('read');
% - Read serial buffer, and return button or trigger event and time, if
% any. If there is no event, both output will be empty. The time is alway a
% scalar even if there are multiple events.
% 
% nEvents = RTBoxSimple('EventsAvailable');
% - Returns number of available events in the buffer. This is even faster
% than RTBoxSimple('read').  
% 
% enabledEvents = RTBoxSimple('enable', 'release'); 
% RTBoxSimple('disable', 'press');
% - Enable/disable the detection of passed events. The events to enable /
% disable can be one of the 5 strings: 'press' 'release' 'pulse' 'light'
% and 'TR', or cellstr containing any of these 5 strings. The string 'all'
% is a shortcut for all the 5 types of events. By default, only 'press' is
% enabled. If you want to detect button release time instead of button
% press time, you need to enable 'release', and better to disable 'press'.
% The optional output returns enabled events. If you don't provide any
% events, it means to query the current enabled events. Note that the 
% device will disable a trigger itself after receiving it. RTBox('clear')
% will implicitly enable those triggers you have enabled.
% 
% RTBoxSimple('TTL', eventCode);
% - Send 4-bit TTL to pins 5-8 of DB-25 port (pin 8 is bit 0). The second
% input is event code, from 0 to 15 (default 1 if omitted). It can also be
% a 4-bit binary string, such as '0011'. 
% 
% timing = RTBoxSimple('WaitTR'); 
% - Wait for TR (TTL input from pin 7 of DB-9 port), and optionally return
% its time. This command will enable TR detection automatically, so you do
% not need to do it by yourself. You can press key 5 to simulate TR for
% testing.
% 
% RTBoxSimple('close');
% - Close the device.
% 
% RTBoxSimple('fake', 1);
% - This allows you to test your code without a device connected. If you
% set fake to 1, you code will run without "device not found" complain, and
% you can use keyboard to respond. The time and button name will use those
% from KbCheck. To allow your code works under fake mode, the button names
% must be supported key names returned by RTBox('KeyNames'). Some commands
% will be ignored silently at fake mode. It is recommended you set fake to
% 1 in the Command Window before you test your code. Then you can simply
% clear all to exit fake mode. If you want to use keyboard for experiment,
% you can insert RTBox('fake',1) in your code before any RTBox call. Then
% if you want to switch to response box, remember to change 1 to 0. 

% History:
% 06/2010, wrote it. Xiangrui Li
% 04/2011, bug fixes and more help text
% 06/2012, if asking close, don't open port

nIn=nargin; % # of input
switch nIn % deal with variable number of input
    case 0, in1='read'; in2=[];
    case 1, in1=varargin{1}; in2=[];
    case 2, [in1, in2]=varargin{1:2};
    otherwise, error('Too many input arguments.');
end
cmd=lower(in1);  % make command and trigger case insensitive

persistent info s; % struct containing important device info
persistent events4enable enableCode; % only to save time
if isempty(info) % no any opened device
    info=struct('events',{{'0' '5' 'light' 'pulse' '4' '3' '2' '1'}},...
        'enabled',logical([1 0 0 0 0]),'portname','','fake',false);
    events4enable={'press' 'release' 'pulse' 'light' 'tr' 'all'};
    enableCode='DUPOFA'; % char to enable above events, lower case to disable
    evalc('GetSecs;KbCheck;WaitSecs(0.001);IOPort(''Verbosity'');now;'); % initialize timing functions
end

if info.fake || strcmp('fake',cmd) % fake mode?
    if strcmp('fake',cmd)
        if isempty(in2), varargout{1}=info.fake; return; end
        info=RTBoxFake('fake',info,in2); 
        if nargout, varargout{1}=info.fake; end
        return; 
    end
    if nargout==0, info=RTBoxFake(cmd,info,in2);
    else varargout{1}=RTBoxFake(cmd,info,in2);
    end
    return; 
end
if isempty(s) && ~strcmp(cmd, 'close'), openRTBox; end

switch cmd
    case 'ttl' % send TTL
        if isempty(in2), in2=1; end % default event code
        if ischar(in2), in2=bin2dec(in2); end % can be binary string
        if info.version<3.2
            in2=dec2bin(in2,4);
            in2=bin2dec(in2(4:-1:1)); % reverse bit order
        end
        IOPort('Write',s,uint8(in2)); % send
    case 'eventsavailable'
        varargout{1}=IOPort('BytesAvailable',s);
    case 'waittr' % wait for scanner TR, for v3.0 or later
        enableEvent('aF'); % enable only TR
        while 1
            if IOPort('BytesAvailable',s),t=GetSecs; break; end
            [key, t]=ReadKey({'5' 'esc'}); % check key press
            if any(strcmp(key,'5')), break
            elseif strcmp(key,'esc'), error('User Pressed ESC. Exiting.'); 
            end
            WaitSecs(0.005); % allow serial buffer updated
        end
        enableEvent(enableCode(info.enabled(1:2))); % restore button
        if nargout, varargout{1}=t; end
    case 'read'
        [b, t]=IOPort('Read',s);
        nevent=numel(b);
        if nevent==0, varargout={'',[]}; return; end
        event=repmat({''},[1 nevent]);
        for i=1:nevent
            b8=dec2bin(b(i),8)=='1';
            event{i}=info.events{b8};
        end
        if numel(event)==1, event=event{1}; end % if only 1 event, use string
        varargout={event,t};
    case 'clear'
        if any(info.enabled(3:5))
            str=enableCode(3:5); 
            enableEvent(str(info.enabled(3:5))); % enable trigger if applicable
        else IOPort('Purge',s);
        end 
    case {'enable' 'disable'} % enable/disable event detection
        if nIn<2 % no event, return current state
            varargout{1}=events4enable(info.enabled);
            return;
        end
        isEnable=strcmp(cmd,'enable');
        str=enableCode; % upper case to enable
        if ~isEnable, str=lower(str); end % lower case to disable
        in2=lower(cellstr(in2));
        for i=1:numel(in2)
            ind=strcmp(in2{i},events4enable); % 1 to 6
            if ~any(ind), RTBoxError('invalidEnable',events4enable); end
            enableEvent(str(ind));
            if ind(6), ind=true(1,5); end % all
            info.enabled(ind)=isEnable; % update state
        end
        if nargout, varargout{1}=events4enable(info.enabled); end
        if ~any(info.enabled), RTBoxWarn('allDisabled',info.ID); end
    case 'close' % close the port
        if ~isempty(s), IOPort('Close',s); end % close port
        info=[]; % delete the slot
    otherwise, RTBoxError('unknownCmd',in1);
end % end of switch. Following are nested functions called by main function

    % send enable/disable str
    function enableEvent(str)
        for ie=1:numel(str)
            for ir=1:4 % try in case of failure
                IOPort('Purge',s);
                IOPort('Write',s,str(ie)); % send single char
                if IOPort('Read',s,1,1)==str(ie), break; end % feedback
                if ir==4, RTBoxError('notRespond'); end
            end
        end
    end

    % find and open first available RT box. 
    function openRTBox
        % get possible port list for different OS
        if IsWin
            % suppose you did not assign RTBox to COM1 or 2
            ports=cellstr(num2str((3:256)','\\\\.\\COM%i'));
            ports=regexprep(ports,' ',''); % needed for matlab 2009b
        elseif IsOSX
            ports=dir('/dev/cu.usbserialRTBox*');
            if isempty(ports), ports=dir('/dev/cu.usbserial*'); end
            if ~isempty(ports), ports=strcat('/dev/',{ports.name}); end
        elseif IsLinux
            ports=dir('/dev/ttyUSB*');
            if ~isempty(ports), ports=strcat('/dev/',{ports.name}); end
        else error('Unsupported system: %s.', computer);
        end

        nPorts=numel(ports);
        if nPorts==0, RTBoxError('noUSBserial'); end
        deviceFound=0; 
        rec=struct('avail','','busy',''); % for error record only
        verbo=IOPort('Verbosity',0); % shut up screen output and error
        cfgStr='BaudRate=115200 ReceiveTimeout=1 PollLatency=0';
        for ic=1:nPorts
            port=ports{ic};
            [s, errmsg]=IOPort('OpenSerialPort',port,cfgStr);
            if s>=0  % open succeed
                IOPort('Purge',s); % clear port
                IOPort('Write',s,'X',0); % ask identity, switch to advanced mode
                idn=IOPort('Read',s,1,21); % contains 'USTCRTBOX'
                if ~IsWin && isempty(strfind(idn,'USTCRTBOX'))
                    IOPort('Close',s); % try to fix ID failure in MAC and Linux
                    s=IOPort('OpenSerialPort',port,cfgStr);
                    IOPort('Write',s,'X',0);
                    idn=IOPort('Read',s,1,21);
                end
                if numel(idn)==1 && idn=='?' % maybe in boot
                    IOPort('Write',s,'R',0); % return to application
                    IOPort('Write',s,'X',0);
                    idn=IOPort('Read',s,1,21);
                end
                if strfind(idn,'USTCRTBOX'), deviceFound=1; break; end
                rec.avail{end+1}=port; % exist but not RTBox
                IOPort('Close',s); % not RTBox, close it
            elseif isempty(strfind(errmsg,'ENOENT'))
                rec.busy{end+1}=port; % open failed but port exists
            end
        end
        if ~deviceFound % issue error
            info=[];
            RTBoxError('invalidPort',rec);  % Windows only
        end
        info.portname=port; % store info
        IOPort('Write',s,'x'); % simple mode
        IOPort('Verbosity',verbo); % restore verbosity
    end
end % end of main function

% put verbose error message here, to make main code cleaner
function RTBoxError(err,varargin)
switch err
    case 'noUSBserial'
        str='No USB-serial ports found. Is your device connected, or driver installed from http://www.ftdichip.com/Drivers/VCP.htm?';
    case 'noDevice'
        [p, info]=deal(varargin{:});
        if isempty(p.avail) && isempty(p.busy) && isempty(info)
            RTBoxError('noUSBserial'); % Windows only
        end
        str='';
        if ~isempty(p.avail) % have available ports
            str=sprintf(['%s Port(s) available: %s, but failed to get identity. ' ...
            'Is any of them the RT device? If yes, try again. ' ...
            'It may help to unplug then plug the device. '],str,cell2str(p.avail));
        end
        if ~isempty(p.busy) % have busy ports
            str=sprintf(['%s Port(s) unavailable: %s, probably used by other program. ' ...
            'Is any of them the RT device? If yes, try ''clear all'' to close the port.'], str, cell2str(p.busy));
        end
        if isempty(str), str='No available port found. '; end
        if ~isempty(info) % have opened RTBox
            str=sprintf('%s Already opened RT device:', str);
            for i=1:numel(info)
                str=sprintf('%s %s at %s,',str,info(i).ID,cell2str(info(i).portname));
            end
            str(end)='.';
        else
            str=sprintf(['%s If you like to test your code without RTBox connected, '...
                'check RTBox fake? for more information.'], str);
        end
    case 'invalidPort'
        p=varargin{1};
        str='';
        if ~isempty(p.avail) % available
            str=sprintf([' Port %s is available, but failed to get identity. ' ...
            'Is it the RT device? If yes, try again. It may help to unplug then plug the device. '],cell2str(p.avail));
        end
        if ~isempty(p.busy) % is busy
            str=sprintf(['%s Port %s is not available, probably used by other program. ' ...
            'Is it the RT device? If yes, try ''clear all'' to close the port.'], str, cell2str(p.busy));
        end
    case 'unknownCmd'
        str=sprintf('Unknown command: %s', varargin{1});
    case 'notRespond'
        str=sprintf('Failed to communicate with device. Try to close and re-connect the device.');
    case 'invalidEnable'
        str=sprintf('Valid events for enable/disable: %s.',cell2str(varargin{1}));
        subFuncHelp(mfilename,'Enable?');
    case 'portNotExist'
        str=sprintf('The specified port %s does not exsit.',varargin{1});
    otherwise, str=err;
end
error(['RTBoxSimple:' err],WrapString(str));
end

% Show warning message, but code will keep running.
% For record, this may write warning message into file 'RTBoxWarningLog.txt'
function RTBoxWarn(err,varargin)
switch err
    case 'allDisabled'
        str=sprintf('All event detection has been disabled for %s.', varargin{1});
    case 'fakeMode'
        str=sprintf('RTBox %s working in keyboard simulation mode.',varargin{1});
    case 'notSupported'
        str=sprintf('The command %s is supported only for v%.1f or later.',varargin{1:2});
    otherwise
        str=sprintf('%s. GetSecs = %.1f',err,GetSecs);
end
str=WrapString(str);
fprintf(2,'\n Warning: %s\n',str);
end

% return str from cellstr for printing, also remove port path
function str=cell2str(Cstr)
    if isempty(Cstr), str=''; return; end
    str=cellstr(Cstr);
    str=strrep(str,'\\.\',''); % Windows path for ports
    str=strrep(str,'/dev/','');  % MAC/Linux path for ports
    str=sprintf('%s, ',str{:}); % convert cell into str1, str2,
    str(end+(-1:0))=''; % delete last comma and space
end

% This will call WaitTill to read keyboard
function [info, varargout]=RTBoxFake(cmd,info,in2)
    keys=unique(info.events(1:4));
    switch cmd
        case 'eventsavailable'
            varargout{1}=numel(ReadKey(keys));
        case 'read'
            if isempty(in2), in2=0.1; end
            if info.untilTimeout, tout=in2;
            else tout=GetSecs+in2;
            end
            while GetSecs<tout
                k=ReadKey(keys);
                if isempty(k), WaitSecs(0.2); continue; 
                else varargout={k}; return;
                end
            end
        case 'waittr'
            [k, varargout{1}]=WaitTill('5'); %#ok<ASGLU>
        case 'ttl'
            if nargout>1, varargout={GetSecs 0}; end
        case {'enable' 'disable'}
            if isempty(in2) || nargout>1
                varargout{1}='press';
            end
        case 'close'
            clear RTBoxSimple;
        case 'fake'
            if in2 && info.fake==0, RTBoxWarn('fakeMode',info.ID); end
            info.fake=in2;
        otherwise % purge, clockratio etc
            if nargout>1, varargout{1}=1; end
    end
end
