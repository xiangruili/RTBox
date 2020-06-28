classdef RTBoxClass < handle
% Control USTC Response Time Box. For principle of the hardware, check the
% paper at https://link.springer.com/article/10.3758/BRM.42.1.212
%
%   doc RTBoxClass % show help of class methods
%
% See RTBoxClass_demo for how to use

% 170422 wrote it based on RTBox.m (xiangrui.li at gmail.com)
% 170612 bug fix instances(closeAll): use reversed order to close.
% 170904 SyncClocks(): read all once; won't return method3 diff.
%        box.clear() default 9 trials.
% 171011 use serIO wrapper.
% 171028 purgeRTBox(): use latency timer to wait.
  
  properties (Hidden); p; kb; end
  properties (Constant, Hidden)
    events4enable = {'press' 'release' 'sound' 'light' 'tr' 'aux'};
  end
  
  methods (Hidden, Static)
    % Add, retrieve, remove RTBoxClass instances (not for fake mode)
    function out = instances(cmd, val)
      persistent boxes; % RTBoxClass instances
      if isempty(boxes)
          try evalc('GetSecs;KbCheck;Screen(''screens'')'); end
      end
      if strcmp(cmd, 'add') % val is instance, append it
        boxes{end+1} = val;
      elseif strcmp(cmd, 'get') % val is boxID, return its instance or ports
        out = {};
        for i = 1:numel(boxes)
          if isequal(boxes{i}.p.boxID, val), out = boxes{i}; return; end
          out{i} = boxes{i}.p.portname; %#ok get in-use ports
        end
      elseif strcmp(cmd, 'remove') % remove input instance
        for i = 1:numel(boxes)
          if boxes{i}==val, boxes(i) = []; return; end
        end
      elseif strcmp(cmd, 'closeAll') % close all serial ports
        for i = numel(boxes):-1:1, close(boxes{i}); end
      end
    end
  end
  
  methods
    function obj = RTBoxClass(boxID)
      % Return class instance for later access.
      %  box = RTBoxClass(); % default boxID=1, most common case to use
      %  box = RTBoxClass([]); % empty boxID means keyboard simulation mode
      %  box2 = RTBoxClass(2); % open 2nd box. boxID can also be string
      % The keyboard simulation mode allows to test stimulus code without RTBox
      % hardware connected.
      if nargin<1, boxID = 1; end
      bPorts = RTBoxClass.instances('get', boxID);
      if ~iscell(bPorts), obj = bPorts; return; end % already open
      
      fake = isempty(boxID);
      obj.p = struct('boxID', boxID, 'fake', fake, 'nEventsRead', 1, ...
        'untilTimeout', false, 'buffer', 585, 'latencyTimer', 0.016, ...
        'events', {{'1' '2' '3' '4' '1' '2' '3' '4' 'sound' 'light' '5' 'aux' 'serial'}}, ...
        'enabled', logical([1 0 0 0 0 0]), 'sync', 0, 'clkRatio', 1, ...
        'TTLWidth', 0.00097, 'debounceInterval', 0.05, ...
        'TTLresting', logical([0 1]), 'threshold', 1);
      if fake, obj.kb = KbEventClass(obj.p.events(1:4)); return; end
      
      [port, st] = RTBoxPorts(bPorts); % open first available RTBox
      if isempty(port), RTBoxError('noDevice', st, bPorts); end

      v = st.version;
      obj.p.cleanObj = onCleanup(@()closePort(st.ser)); % set early
      if ~(v>=4.3 || (v>1.9 && v<2))
        error('Firmware not supported. Please update to latest firmware');
      end
      if (v>=6 && v<6.1) || (v>=5 && v<5.2) || (v>=4 && v<4.7) || v<1.91
        RTBoxWarn('updateFirmware');
      end
      
      % Store params
      obj.p.ser = st.ser;
      obj.p.version = v;
      obj.p.portname = port;
      obj.p.MAC = st.MAC;
      obj.p.latencyTimer = st.latencyTimer;
            
      % Read TTL params, threshold, debounceInterval from EEPROM
      b = readEEPROM(st.ser, 224, 6);
      obj.p.TTLWidth = (255-b(1)) / 7200;
      if obj.p.TTLWidth==0, obj.p.TTLWidth = Inf; end
      obj.p.TTLresting = bitget(b(2), 1:2);
      obj.p.threshold = bitget(b(2), [4 7]) * (1:2)' + 1;
      obj.p.debounceInterval = 256.^(0:3) * b(3:6)' / 921600;
      
      % Get clockRatio
      for i = 0:15 % arbituary # of host computers for a box
        b14 = readEEPROM(st.ser, i*14, 14);
        if all(b14(1:6)==255), break; end % EEPROM not written
        if isequal(obj.p.MAC(2:7), b14(9:14)), break; end % found it
      end
      if i==15, i = 0; end % all slots written
      obj.p.MAC(1) = uint8(i*14);
      if ~all(diff(b14(1:6))==0) % just to be safe
        ratio = typecast(uint8(b14(1:8)), 'double');
        if abs(ratio-1)<0.01, obj.p.clkRatio = ratio; end
      end
      if obj.p.clkRatio==1, RTBoxWarn('clockRatioUncorrected'); end
      
      obj.p.sync = syncClocks(obj, 9, 1:6); % also enable events
      if obj.p.sync(2) > 2.5e6,  reset(obj); end % ~1 month power on
      RTBoxClass.instances('add', obj);
      
      % local functions called by constructor      
      function closePort(s)
        try %#ok<*TRYNC>
          evalc('serIO(''Write'', s, ''x'');'); % simple mode
          serIO('Close', s);
        end
      end
      
      function b = readEEPROM(s, addr, nBytes)
        serIO('Read', s);
        serIO('Write', s, uint8([17 addr nBytes]));
        b = serIO('Read', s, nBytes);
        if numel(b)<nBytes, b = readEEPROM(s, addr, nBytes); end
      end
      
    end
    
    function n = eventsAvailable(obj)
      % Return the number of available events in the buffer.
      % Unlike other read functions, the events in the buffer will be untouched
      % after this call. This normally takes <1 ms to return, so it is safe to
      % call between video frames. Note that the returned nEvents may have a
      % fraction, which normally indicates data is coming in.
      if obj.p.fake
          n = PsychHID('KbQueueFlush', obj.kb.deviceIndex, 0);
          if ~all(obj.p.enabled(1:2)), n = n/2; end % guess press/release half/half
          return;
      end
      n = serIO('BytesAvailable', obj.p.ser) / 7;
    end
    
    function varargout = TTL(obj, eCode)
      % Send an event code to DB25 port, and return sending time.
      % Send TTL to DB-25 port (pin 8 is bit 0). The event code (default 1),
      % is 4-bit (0~15) for version<5, and 8-bit (0~255) for v>=5. It can also
      % be equivalent binary string, such as '0011'. The optional output are
      % the time the TTL was sent, and its upper bound. The width and polarity
      % of TTL are configurable.
      if obj.p.fake, if nargout, varargout = {GetSecs 0}; end; return; end
      v = obj.p.version;
      if nargin<2 || isempty(eCode), eCode = 1; end % default
      if ischar(eCode), eCode = bin2dec(eCode); end %binary string
      if v>=5, b = [1 eCode]; else, b = eCode; end
      [tSend, tpost] = serIO('Write', obj.p.ser, uint8(b)); % send
      
      maxTTL = 255; if v<5, maxTTL = 15; end
      if eCode<0 || eCode>maxTTL || eCode~=round(eCode)
        RTBoxError('invalidTTL', maxTTL);
      end
      ub = tpost-tSend;
      tSend = tSend + 8.68e-05 * ((v>=5)+1); % (8+2)/115200
      if nargout, varargout = {tSend ub}; end
      if v<3, RTBoxWarn('notSupported', 'TTL', 3); return; end
      if ub>0.005, RTBoxWarn('USBoverload', ub); end
    end
    
    function clear(obj, nSyncTrial)
      % This clears serial buffer to prepare for receiving response in a trial.
      %
      % This also synchronizes the clocks of computer and device, and enables
      % the detection of trigger event if applicable. It is designed to run
      % right before stimulus onset of each trial.
      %
      % The optional input nSyncTrial, default 9, is the number of trials to
      % synchronize clocks. Set it to 0 to skip the synchronization when you
      % measure RT relative to a trigger, or when you want to return boxSecs.
      if obj.p.fake, return; end
      if nargin<2 || isempty(nSyncTrial), nSyncTrial = 9; end
      if nSyncTrial>0
        obj.p.sync = syncClocks(obj, nSyncTrial, 1:6); % sync clocks
      elseif any(obj.p.enabled(3:6))
        enableByte(obj);
      else, purgeRTBox(obj.p);
      end
    end
    
    function dIn = digitalIn(obj, toReverse)
      % Return the digital input from pins 1~8 at DA-15 port.
      %
      % The pins 1~4 are also connected to button 1~4. All 8 pins are pulled up,
      % so the original high level means resting state. If the optional input,
      % toReverse is provided to and is ture, this will return reversed level.
      %  dIn = box.digitalIn(); % resting will 0xFF
      %  dIn = box.digitalIn(1); % resting will 0x00
      if obj.p.fake; dIn = []; return; end
      if obj.p.version<5
          RTBoxWarn('notSupported', 'digitalIn', 5);
          dIn = []; return;
      end
      if obj.p.version<5.22 || (obj.p.version>6 && obj.p.version<6.12)
          RTBoxWarn('updateFirmware');
          dIn = []; return;
      end
      s = obj.p.ser;
      for iTry = 1:4 % try in case of failure
        purgeRTBox(obj.p); % clear buffer
        serIO('Write', s, uint8(8));
        b = serIO('Read', s, 2);
        if numel(b)==2 && b(1)==8, break; end
        if iTry==4, RTBoxError('notRespond'); end
      end
      dIn = uint8(b(2));
      if nargin>1 && toReverse, dIn = 255 - dIn; end
    end
    
    function dt = clockDiff(obj, nSyncTrial)
      % Return offset between host and RTBox clock without updating the offset.
      if obj.p.fake, dt = [0 GetSecs 0]; return; end
      if nargin<2 || isempty(nSyncTrial), nSyncTrial = 20; end
      dt = syncClocks(obj, nSyncTrial);
    end
    
    function t = waitTR(obj)
      % Wait for TR, and return accurate TR time based on computer clock.
      % This command enables TR detection, so there is need to do it explicitly.
      % This also detects TR key, 5 for example, so one can simulate TR by
      % keyboard press.
      if obj.p.fake, t = obj.kb.read(obj.p.events{11}); return; end
      s = obj.p.ser;
      enableByte(obj, 16); % enable only TR
      clnObj = onCleanup(@()enableByte(obj)); % restore events
      tr = obj.p.events{11};
      while 1
        if serIO('BytesAvailable', s) >= 7
          if nargout
            b7 = serIO('Read', s, 7);
            t = bytes2secs(b7(2:7)', obj.p.clkRatio);
            obj.p.sync = syncClocks(obj, 10); % new sync
            t = t + obj.p.sync(1);
          end
          break;
        end
        t = KbEventClass.check(tr); % check key press
        if ~isempty(t), break; end
        KbEventClass.esc_exit();
        WaitSecs('YieldSecs', 0.01);
      end
    end
    
    function [timing, event] = secs(obj, tout)
      % Return host time and names of events.
      % events are normally button press, but can also be button release, sound,
      % light, 5 (tr, v3+), aux (v5+) and serial. If you changed button names by
      % buttonNames(), the button-down and up events will be your button names. If
      % you enable both button down and up events, the name for a button-up event
      % will be its button name plus 'up', such as '1up', '2up' etc. timing are
      % for each event, using GetSecs timestamp. If there is no event, both output
      % will be empty.
      %
      % The timeout input can have two meanings. By default, timeout is the
      % seconds (default 0.1 s) to wait from the evocation of the command.
      % Sometimes, you may like to wait until a specific time, for example till
      % GetSecs clock reaches TillSecs. Then you can use
      % box.secs(TillSecs-GetSecs), but it is better to set the timeout to until
      % time, so you can simply use box.secs(TillSecs). You do this by
      % box.untilTimeout(1). During timeout wait, you can press ESC to abort your
      % program. box.secs(0) will take couple of milliseconds to return after
      % several evokes, but this is not guaranteed. If you want to check response
      % between two video frames, use box.eventsAvailable() instead.
      %
      % This function will return when either time is out, or required events are
      % detected. If there are events available in the buffer, this will read back
      % all of them. To set the number of events to wait, use box.nEventsRead(n).
      if nargin<2 || isempty(tout), tout = 0.1; end
      [timing, event] = readFcn(obj, tout, 'secs');
    end
    
    function [timing, event] = boxSecs(obj, tout)
      % Return RTBox time and names of events.
      % This is the same as box.secs(), except that the returned time is based on
      % the box clock, normally the seconds since the device is powered.
      if nargin<2 || isempty(tout), tout = 0.1; end
      [timing, event] = readFcn(obj, tout, 'boxsecs');
    end
    
    function [timing, event] = light(obj, tout)
      % Return response time (relative to light trigger) and names of events.
      % This is the same as box.secs(), except that the returned time is relative
      % to light onset.
      if nargin<2 || isempty(tout), tout = 0.1; end
      [timing, event] = readFcn(obj, tout, 'light');
    end
    
    function [timing, event] = sound(obj, tout)
      % Return response time (relative to sound trigger) and names of events.
      % This is the same as box.secs(), except that the returned time is relative
      % to sound onset.
      if nargin<2 || isempty(tout), tout = 0.1; end
      [timing, event] = readFcn(obj, tout, 'sound');
    end
    
    function [timing, event] = TR(obj, tout)
      % Return response time (relative to TR trigger) and names of events.
      % This is the same as box.secs(), except that the returned time is relative
      % to TR trigger.
      if nargin<2 || isempty(tout), tout = 0.1; end
      [timing, event] = readFcn(obj, tout, 'tr');
    end
    
    function [timing, event] = aux(obj, tout)
      % Return response time (relative to sound trigger) and names of events.
      % This is the same as box.secs(), except that the returned time is relative
      % to aux trigger.
      if nargin<2 || isempty(tout), tout = 0.1; end
      [timing, event] = readFcn(obj, tout, 'aux');
    end
    
    function isDown = buttonDown(obj)
      % Return logical array of length 4, indicating if 4 buttons are pressed
      if obj.p.fake, isDown = false(1,4); return; end
      s = obj.p.ser;
      v = obj.p.version;
      enableByte(obj, 0); % disable all detection
      serIO('Write', s, '?'); % ask button state: '4321'*16 63
      b2 = serIO('Read', s, 2); % ? returns 2 bytes
      enableByte(obj, 2.^(0:1)*obj.p.enabled(1:2)'); % enable detection
      if numel(b2)~=2 || ~any(b2==63), RTBoxError('notRespond'); end
      b2 = b2(b2~=63); % '?' is 2nd byte for old version
      if v>=4.7 || (v>1.9 && v<2)
        b2 = bitget(b2, 1:4);
      else
        b2 = bitget(b2, 5:8); % most significant 4 bits are button states
      end
      isDown = logical(b2);
    end
    
    function varargout = enableState(obj)
      % Return the enabled events in hardware.
      % This may not be consistent with those returned by enable(), since an
      % external trigger will disable the detection of itself in the hardware,
      % while the state in the Matlab code is still enabled. clear() will enable
      % the detection implicitly. This command is mainly for debug purpose.
      for i = 1:99
        serIO('Read', obj.p.ser);
        serIO('Write', obj.p.ser, 'E'); % ask enable state
        b2 = serIO('Read', obj.p.ser, 2); % return 2 bytes
        if numel(b2)==2 && b2(1)=='E', break; end
        if i==4, RTBoxError('notRespond'); end
      end
      b2 = logical(bitget(b2(2), 1:6)); % least significant 6 bits
      varargout{1} = obj.events4enable(b2);
    end
    
    function varargout = buttonNames(obj, newNames)
      % Set/query four button names.
      % The default names are {'1' '2' '3' '4'}. You can use any names, except
      % 'sound', 'pulse', 'light', '5', and 'serial', which are reserved for other
      % events. If no input mean to query current button names.
      oldNames = obj.p.events(1:4);
      if nargin<2, varargout{1} = oldNames; return; end
      if isempty(newNames), newNames = {'1' '2' '3' '4'}; end
      if numel(newNames)~=4 || ~iscellstr(newNames)
        RTBoxError('invalidButtonNames');
      end
      
      if ~isempty(intersect(newNames, obj.p.events(9:end)))
      	RTBoxError('conflictName', 'buttonNames', obj.p.events(9:end));
      end
      obj.p.events(1:8) = [newNames newNames];
      if all(obj.p.enabled(1:2))
        obj.p.events(5:8) = strcat(newNames, 'up');
      end
      if nargout, varargout{1} = oldNames; end
    end
    
    function varargout = enable(obj, evnts)
      % This enables the detection of named events.
      % The events to enable can be one or more these strings: 'press' 'release'
      % 'sound' 'pulse' 'light' 'TR' or 'aux'. The string 'all' is a shortcut for
      % all the events. The optional output returns enabled events. If you don't
      % provide any input, it means to query the current enabled events. Note that
      % the device will disable a trigger itself after receiving it. clear() will
      % implicitly enable those triggers after self disabling.
      if nargin<2, varargout{1} = obj.events4enable(obj.p.enabled);return; end
      if nargout, varargout{1} = enable_disable(obj, evnts, true);
      else, enable_disable(obj, evnts, true); end
    end
    
    function varargout = disable(obj, evnts)
      % This disables the named events, opposite to enable()
      if nargin<2, varargout{1} = obj.events4enable(obj.p.enabled);return, end
      if nargout, varargout{1} = enable_disable(obj, evnts, false);
      else, enable_disable(obj, evnts, false); end
    end
    
    function varargout = clockRatio(obj, secsTest)
      % Measure and apply the clock ratio of computer/RTBox.
      % The ratio is saved in the hardware for later use. The optional input
      % specifies how long the test will last (default 30 s). If you want to
      % return host time, it is better to do this once before experiment.
      if obj.p.fake, varargout{1} = 1; return; end
      if nargout, varargout{1} = obj.p.clkRatio; return; end
      if nargin<2 || isempty(secsTest), secsTest = 30; end
      interval = 1; % interval between trials
      nTrial = max(10, round(secsTest/interval)); % # of trials
      fprintf(' Measuring clock ratio. Trials remaining:%4.f', nTrial);
      enableByte(obj, 0); % disable all
      t = zeros(nTrial,3); t0 = GetSecs;
      for i = 1:nTrial
        t(i,:) = syncClocks(obj, 40); % update info.sync
        KbEventClass.wait(t0+interval*i);
        fprintf('\b\b\b\b%4d', nTrial-i);
      end
      fprintf('\n');
      
      t = bsxfun(@minus, t, mean(t));
      [slope, se] = lscov(t(:,2), t(:,1));
      
      obj.p.clkRatio = obj.p.clkRatio*(1+slope); % update clock ratio
      if nargout
        varargout{1} = obj.p.clkRatio;
      else
        fprintf(' Clock ratio (computer/box): %.8f +- %.8f\n', ...
          obj.p.clkRatio, se);
      end
      
      if se>1e-4, RTBoxWarn('ratioBigSE', se); end
      if abs(slope)>0.01
        obj.p.clkRatio = 1;
        RTBoxError('ratioErr', slope);
      end
      
      if nTrial >= 20
        b8 = typecast(obj.p.clkRatio, 'uint8');
        writeEEPROM(obj, obj.p.MAC(1), [b8(:)' obj.p.MAC(2:7)]);
      end
      obj.p.sync = syncClocks(obj, 10, 1:2); % use new ratio
    end
    
    function varargout = TTLWidth(obj, newWidth)
      % Set/get TTL width in seconds.
      % The default width is ~0.001 s. The actual width may have some variation.
      % The supported width by the hardware ranges from 0.14e-3 to 35e-3 secs. The
      % infinite width is also supported. Infinite width means the TTL will stay
      % until it is changed by next TTL(), such as TTL(0).
      if nargin<2, varargout{1} = obj.p.TTLWidth; return; end
      if nargout, varargout{1} = obj.p.TTLWidth; end
      wUnit = 1/7200; % 0.139e-3 s, width unit, not very accurate
      if isempty(newWidth), newWidth = 0.00097; end
      if isinf(newWidth), newWidth = 0; end
      if (newWidth<wUnit*0.9 || newWidth>wUnit*255*1.1) && newWidth>0
        RTBoxWarn('invalidTTLwidth');
      end
      width = double(uint8(newWidth/wUnit))*wUnit; % real width
      writeEEPROM(obj, 224, uint8(255-width/wUnit));
      if newWidth>0 && abs(width-newWidth)/newWidth>0.1
        RTBoxWarn('widthOffset', width);
      end
      if width==0, width = inf; end
      obj.p.TTLWidth = width;
    end
    
    function varargout = TTLResting(obj, newPol)
      % Set/get TTL polarity for DB-25 port.
      % Value 0 means low TTL resting. The first value is for DB-25 pins 1~8, and
      % the second is for pins 17~24 which is applicale to only v>=5.
      if nargin<2, varargout{1} = obj.p.TTLresting; return; end
      if nargout, varargout{1} = obj.p.TTLresting; end
      if isempty(newPol), newPol = logical([0 1]); end
      obj.p.TTLresting = newPol;
      if numel(newPol)>2, newPol = newPol(1:2);
      elseif numel(newPol)<2, newPol(2) = obj.p.TTLresting(2);
      end
      
      thr = bitget(obj.p.threshold-1, 1:2);
      b = 2 .^ [0 1 3 6] * [newPol thr]';
      writeEEPROM(obj, 225, uint8(b));
    end    
    
    function varargout = threshold(obj, thr)
      % Set/get threshold for sound and light trigger (v5+ only).
      % There are four levels (1:4) of the threshold. Default (1) is the lowest.
      % If, for example, the background light is relatively bright and the device
      % detects light trigger at background, you can increase the threshold to a
      % higher level.
      if nargin<2, varargout{1} = obj.p.threshold; return; end
      if nargout, varargout{1} = obj.p.threshold; end
      if obj.p.version<5, RTBoxWarn('notSupported', 'threshold', 5); return; end
      if isempty(thr), thr = 1; end
      thr = round(thr);
      thr = max(min(thr, 4), 1);
      obj.p.threshold = thr;
      
      b = 2 .^ [0 1 3 6] * [obj.p.TTLresting bitget(thr-1, 1:2)]';
      writeEEPROM(obj, 225, uint8(b));
    end
    
    function reset(obj)
      % Restart firmware and reset the device clock to zero (rarely needed).
      s = obj.p.ser;
      serIO('Write', s, 'xBS'); % simple mode, boot, bootID
      serIO('Write', s, 'R'); % return, so restart
      serIO('Write', s, 'X'); % advanced mode
      serIO('Read', s, 7+21); % clear buffer
      obj.p.sync = syncClocks(obj, 10, 1:2);
    end
    
    function varargout = debounceInterval(obj, intvl)
      % Set/get debounce interval in seconds (default 0.05).
      % RTBox hardware ignores both button down and up events within intvl window
      % after an event of the same button. intvl=0 will disable debouncing.
      if nargin<2, varargout{1} = obj.p.debounceInterval; return; end
      if nargout, varargout{1} = obj.p.debounceInterval; end
      if isempty(intvl), intvl = 0.05; end
      if ~isscalar(intvl) || ~isnumeric(intvl) || intvl<0
        RTBoxError('invalidValue', 'debounceInterval');
      end
      obj.p.debounceInterval = intvl;
      b4 = typecast(uint32(intvl*921600), 'uint8');
      writeEEPROM(obj, 226, b4);
    end
    
    function varargout = untilTimeout(obj, newBool)
      % Set/query absolute/relative waiting for read functions, like secs().
      % By default, read functions don't use until timeout, but use relative
      % timeout. For example, secs(2) will wait for 2 seconds from now. One may
      % like to let secs(timeout) wait till GetSecs clock reaches timeout, then
      % set newBool to 1.
      oldVal = obj.p.untilTimeout;
      if nargin<2, varargout{1} = oldVal; return; end
      if isempty(newBool), newBool = false; end
      obj.p.untilTimeout = logical(newBool);
      if nargout, varargout{1} = oldVal; end
    end
    
    function varargout = nEventsRead(obj, N)
      % Set/query the number of events (default 1) to wait during read functions.
      % For trigger-relative reading, like light(), this refers to the number of
      % events besides the trigger. If
      oldVal = obj.p.nEventsRead;
      if nargin<2, varargout{1} = oldVal; return; end
      if isempty(N), N = 1; end
      obj.p.nEventsRead = N;
      if nargout, varargout{1} = oldVal; end
    end
    
    function varargout = bufferSize(obj, nEvents)
      % Set/get input serial buffer size in number of events.
      % The default buffer can hold about 585 events, which is enough for most
      % experiments. If you need to buffer more events and read all once after
      % long period of time, you can set a new larger number.
      oldVal = obj.p.buffer;
      if nargin<2, varargout{1} = oldVal; return; end
      if nargout, varargout{1} = oldVal; end
      if isempty(nEvents), nEvents = 585; end
      obj.p.buffer = nEvents;
      if obj.p.fake, return; end
      bytes = ceil(nEvents*7/8)*8 *[1 1];
      str = sprintf('InputBufferSize=%i HardwareBufferSizes=%i,4096', bytes);
      serIO('Configure', obj.p.ser, str);
    end
    
    function varargout = TRKey(obj, newKey)
      % Set/query TR key (like MRI scanner trigger).
      % The default is number key '5' on either main keyboard or number pad. In
      % case your TR key is not '5', you can set it by this command. Then
      % waitTR() will detect the newKey, and you can press newKey to simulate TR
      % trigger. Note that the newKey must be valid key name, and must not use
      % button names and other trigger names.. RTBoxClass.keyName() will show
      % the names of pressed keys.
      if nargin<2, varargout{1} = obj.p.events{11}; return; end
      if nargout, varargout{1} = obj.p.events{11}; end
      if isempty(newKey), newKey = '5'; end
      if ~ischar(newKey), RTBoxError('invalidStr', 'TRKey'); end
      inUse = obj.p.events; inUse(11) = []; inUse = unique(inUse);
      if any(strcmpi(newKey, inUse)), RTBoxError('conflictName', 'TRKey', inUse); end
      obj.p.events{11} = newKey;
    end
    
    function test(obj)
      % Quick command line check for events.
      % This will wait for incoming event, and display event name and time.
      t0 = GetSecs - obj.p.sync(1);
      fprintf(' Waiting for events. Press ESC to stop.\n');
      fprintf('%9s%9s-%.4f\n', 'Event', 'secs', t0);
      while 1
        WaitSecs('YieldSecs', 0.02);
        try [t, event] = boxSecs(obj);
        catch me
            if strncmpi(me.message, 'User pressed ESC', 16), break;
            else, rethrow(me);
            end
        end
        for i = 1:numel(t)
          fprintf('%9s%12.4f\n', event{i}, t(i)-t0);
        end
      end
    end
    
    function info(obj)
      % Display some parameters of the device and host.
      % When you report possible problem for the hardware or the code, please
      % copy and paste the screen output of this command.
      os = '';
      if ispc
          if exist('system_dependent', 'builtin'), os = system_dependent('getos');
          else, [~, os] = system('ver 2>&1');
          end
      elseif ismac
          [~, os] = system('sw_vers -productVersion 2>&1');
      elseif isunix
          [err, os] = system('lsb_release -a 2>&1');
          if err
              [~, os] = system('cat /etc/os-release');
              os = regexp(os, '(?<=PRETTY_NAME=").*?(?=")', 'match', 'once');
          else
              os = regexp(os, '(?<=Description:\s*).*?(?=\n)', 'match', 'once');
          end
      end

      serV = serIO('Version');
      drv = which(serV.module); i = strfind(drv, filesep); drv = drv(i(end)+1:end);
      if exist('OCTAVE_VERSION', 'builtin'), lang = 'Octave'; else, lang = 'Matlab'; end
      
      fprintf(' Computer: %s (%s)\n', computer, strtrim(os));
      fprintf(' %s: %s\n', lang, version);
      fprintf(' %s: %s\n', drv, serV.version);
      fprintf(' RTBoxClass.m rev %s\n', RTBoxCheckUpdate());
      fprintf(' Number of events to wait: %g\n', obj.p.nEventsRead);
      fprintf(' Use until-timeout for read: %g\n', obj.p.untilTimeout);
      if obj.p.fake
        fprintf(2, ' RTBoxClass.m is at keyboard simulation mode\n');
        return;
      end
      v = obj.p.version;
      fprintf(' boxID: %s, firmware v%.4g\n', num2str(obj.p.boxID), v);
      fprintf(' Serial port: %s\n', num2str(obj.p.portname));
      fprintf(' Serial handle: %g\n', obj.p.ser);
      fprintf(' Latency Timer: %g\n', obj.p.latencyTimer);
      fprintf(' Debounce interval: %g\n', obj.p.debounceInterval);
      fprintf([' MAC address(%i): ' repmat('%02X-',1,5) '%02X\n'], obj.p.MAC);
      fprintf(' GetSecs/BoxClock unit ratio-1: %.2g\n', obj.p.clkRatio-1);
      fprintf(' GetSecs-BoxClock offset: %.5f+%.5f\n', obj.p.sync([1 3]));
      fprintf(' Events enabled: %s\n', cell2str(obj.events4enable(obj.p.enabled)));
      if v >= 3
        fprintf(' TTL resting level: [%g %g]\n', obj.p.TTLresting);
        fprintf(' TTL width: %.2g\n', obj.p.TTLWidth);
      end
      if v >= 5
        fprintf(' Light/Sound threshold: %g\n', obj.p.threshold);
      end
      fprintf(' Number of events available: %g\n\n', eventsAvailable(obj));
    end
    
    function close(obj)
      % This closes the RTBox and release serial port
      RTBoxClass.instances('remove', obj);
      if obj.isvalid, delete(obj); end % invoke closePort()
    end
  end
  
  methods (Hidden)
    function t3 = syncClocks(obj, nr, enableInd)
      % synch clock, and enable event
      s = obj.p.ser;
      if any(obj.p.enabled), enableByte(obj, 0); end % disable all
      t = zeros(nr, 3); % tpre, tpost, tbox
      serIO('Read', s);
      for iTry = 1:4
        for i = 1:nr
          WaitSecs((0.7+rand)/1000); % 0.7 allow 7-byte finish
          [t(i,1), t(i,2)] = serIO('Write', s, 'Y');
        end
        b7 = serIO('Read', s, 7*nr);
        if numel(b7)==7*nr && all(b7(1:7:end)==89), break; end
        if iTry==4, RTBoxError('notRespond'); end
        purgeRTBox(obj.p);
      end
      b7 = reshape(b7, [7 nr]);
      t(:,3) = bytes2secs(b7(2:7,:), obj.p.clkRatio);
      
      [tdiff, i] = max(t(:,1)-t(:,3)); % the latest tpre is the closest to real write
      twin = t(i,2) - t(i,1); % tpost-tpre for the selected sample: upper bound
      tbox = t(i,3); % tbox when diff measured
      t3 = [tdiff+8.68e-05 tbox twin]; % tdiff, its tbox and ub's
      if twin>0.005, RTBoxWarn('USBoverload', twin); end
      if nargin<3, return; end
      b = 0:5; b = b(enableInd); b = 2.^b * obj.p.enabled(enableInd)';
      enableByte(obj, b); % restore enable
    end
    
    function varargout = readFcn(obj, tout, cmd)
      tnow = GetSecs;
      read = {'secs' 'boxsecs' 'sound' 'light' 'tr' 'aux'};
      cmdInd = find(strcmp(cmd, read), 1); % which command
      nEventsRead = obj.p.nEventsRead;
      if cmdInd>2 % relative to trigger
        nEventsRead = nEventsRead+1; % detect 1 more event
        if ~obj.p.enabled(cmdInd)
          RTBoxError('triggerDisabled', obj.events4enable{cmdInd});
        end
      end
      if ~obj.p.untilTimeout, tout = tnow+tout; end % stop time
      varargout = {[], {}}; % return empty if no event detected
      timing = []; event = {};
      if obj.p.fake
        keys = unique(obj.p.events(1:4));
        if ~all(ismember(keys, obj.kb.keyName)), obj.kb.keyName = keys; end
        [varargout{:}] = obj.kb.read(tout-tnow, keys);
        return;
      end
      isReading = false;
      nB = serIO('BytesAvailable', obj.p.ser);
      while (tnow<tout && nB<nEventsRead*7 || isReading)
        WaitSecs('YieldSecs', obj.p.latencyTimer); % update serial buffer
        nB1 = serIO('BytesAvailable', obj.p.ser);
        isReading = nB1>nB; % wait if reading
        nB = nB1;
        tnow = KbEventClass.esc_exit();
      end
      nEvent = floor(nB/7);
      if nEvent<nEventsRead, return; end  % return if not enough events
      b7 = serIO('Read', obj.p.ser, nEvent*7);
      b7 = reshape(b7, [7 nEvent]); % each event contains 7 bytes
      eventcodes = [49:2:55 50:2:56 97 48 57 98 89]; % code for 13 events
      for i = 1:nEvent % extract each event and time
        ind = find(b7(1,i)==eventcodes, 1); % which event
        if isempty(ind)
          RTBoxWarn('invalidEvent', b7(:,i));
          break; % not continue, rest must be messed up
        end
        event{i} = obj.p.events{ind}; %#ok event name
        timing(i) = bytes2secs(b7(2:7,i), obj.p.clkRatio); %#ok box time
      end
      if isempty(timing), return; end
      
      if cmdInd==1 % secs: convert into computer time
        if timing(end)-obj.p.sync(2) > 9 % sync done too long before?
          sync = obj.p.sync(1:2); % last sync for interpolation
          obj.p.sync = syncClocks(obj, 20, 1:2); % update sync
          sync(2,:) = obj.p.sync(1:2); % append current sync
          tdiff = interp1(sync(:,2), sync(:,1), timing); % linear interp
        else, tdiff = obj.p.sync(1);
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
      varargout = {timing, event};
    end
    
    function varargout = enable_disable(obj, in2, isEnable)
      if strcmpi(in2, 'all'), in2 = obj.events4enable; end
      in2 = lower(cellstr(in2));
      foo = uint8(2.^(0:5) * obj.p.enabled');
      for i = 1:numel(in2)
        ind = find(strcmp(in2{i}, obj.events4enable));
        if isempty(ind), RTBoxError('invalidEnable', obj.events4enable); end
        foo = bitset(foo, ind, isEnable);
        obj.p.enabled(ind) = isEnable;
      end
      enableByte(obj, foo);
      if nargout, varargout{1} = obj.events4enable(obj.p.enabled); end
      if all(obj.p.enabled(1:2))
        obj.p.events(5:8) = strcat(obj.p.events(1:4), 'up');
      else
        obj.p.events(5:8) = obj.p.events(1:4);
      end
    end
    
    function writeEEPROM(obj, addr, bytes)
      % Send bytes to write into EEPROM at addr
      if obj.p.fake, return; end
      nBytes = numel(bytes);
      serIO('Write', obj.p.ser, uint8([16 addr nBytes]));
      serIO('Write', obj.p.ser, bytes);
      serIO('Write', obj.p.ser, uint8([3 2])); % extra 2 useless bytes
    end
    
    function enableByte(obj, enByte)
      % send enable byte
      if obj.p.fake, return; end
      s = obj.p.ser;
      if nargin<2, enByte = 2.^(0:5)*obj.p.enabled'; end
      enByte = uint8(enByte);
      enByte = [uint8('e') enByte];
      for iTry = 1:4 % try in case of failure
        purgeRTBox(obj.p); % clear buffer
        serIO('Write', s, enByte);
        if serIO('Read', s, 1)==101, break; end % 'e' feedback
        if iTry==4, RTBoxError('notRespond'); end
      end
    end
    
    % Override inherited methods from handle, except isvalid, make it hidden
    function lh = addlistener(varargin); lh=addlistener@handle(varargin{:}); end
    function lh = listener(varargin); lh=listener@handle(varargin{:}); end
    function p = findprop(varargin); p = findprop@handle(varargin{:}); end
    function lh = findobj(varargin); lh = findobj@handle(varargin{:}); end
    function TF = eq(varargin); TF = eq@handle(varargin{:}); end
    function TF = ne(varargin); TF = ne@handle(varargin{:}); end
    function TF = lt(varargin); TF = lt@handle(varargin{:}); end
    function TF = le(varargin); TF = le@handle(varargin{:}); end
    function TF = gt(varargin); TF = gt@handle(varargin{:}); end
    function TF = ge(varargin); TF = ge@handle(varargin{:}); end
    function notify(varargin); notify@handle(varargin{:}); end
    function delete(obj); close(obj); delete@handle(obj); end
  end
  
  methods (Static)
    function keyName()
      % Show the name of pressed key on keyboard.
      % The name can be used for buttonNames() and TRKey()
      KbEventClass.getName
    end
  end
end % End RTBoxClass

function RTBoxError(err, varargin)
  switch err
    case 'noUSBserial'
        str = ['No USB-serial ports found. Either device is not connected,' ...
            'or driver is not installed (see User Manual for driver info). ' ...
            'If you like to test your code without RTBox connected, ' ...
            'use box = RTBoxClass('''') at fake mode.'];
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
        str = sprintf('%s Already opened RTBox at %s.', str, cell2str(bPorts));
      end
    case 'conflictName'
      str = sprintf('Valid ''%s'' must not be any of these:\n %s.', ...
        varargin{1}, cell2str(varargin{2}));
    case 'invalidButtonNames'
      str = sprintf('ButtonNames requires a cellstr containing four button names.');
      help('RTBoxClass>buttonNames');
    case 'notRespond'
      str = sprintf('Failed to communicate with device. Try to close and re-connect the device.');
    case 'invalidEnable'
      str = sprintf('Valid events for enable/disable: %s.', cell2str(varargin{1}));
      help('RTBoxClass>Enable');
    case 'triggerDisabled'
      str = sprintf('Trigger is not enabled. You need to enable ''%s''.', varargin{1});
    case 'ratioErr'
      str = sprintf(['The clock ratio difference is too high: %2g%%. Your computer ' ...
        'timing probably has problem.'], abs(varargin{1})*100);
    case 'invalidTTL'
      str = sprintf(['TTL value must be integer from 0 to %g, or ' ...
        'equivalent binary string.'], varargin{1});
      help('RTBoxClass>TTL');
    case 'invalidValue'
      str = sprintf('The value for %s must be a numeric scalar.', varargin{1});
      help(['RTBoxClass>' varargin{1}]);
    case 'invalidStr'
      str = sprintf('The value for %s must be a string.', varargin{1});
      help(['RTBoxClass>' varargin{1}]);
    case 'escPressed'
      str = 'User Pressed ESC. Exiting.';
    otherwise, str = err;
  end
  error(['RTBoxClass:' err], WrapString(str));
end

function RTBoxWarn(err, varargin)
  % Show warning message, but code will keep running.
  % For record, this may write warning message into file 'RTBoxWarningLog.txt'
  switch err
    case 'invalidEvent'
      str = sprintf(' %g', varargin{1});
      str = sprintf(['Events not recognized:%s. Please do box.clear() ' ...
        'before showing stimulus.\nGetSecs = %.1f'], str, GetSecs);
    case 'noTrigger'
      str = sprintf('Trigger ''%s'' not detected. GetSecs = %.1f', varargin{1}, GetSecs);
    case 'USBoverload'
      str = sprintf(['Possible system overload detected. This may affect ' ...
        'clock sync.\n twin=%.1fms, '], varargin{1}*1000);
      str = sprintf('%sGetSecs=%.1f', str, GetSecs);
    case 'invalidTTLwidth'
      str = sprintf('Supported TTL width is from %.2g to %.2g s .', [1 255]/7200);
    case 'widthOffset'
      str = sprintf('TTL width will be about %.5f s', varargin{1});
    case 'clockRatioUncorrected'
      str = 'Clock ratio has not been corrected. Please run box.ClockRatio().';
    case 'ratioBigSE'
      str = sprintf('The slope SE is large: %2g. Try longer time for ClockRatio.',varargin{1});
    case 'notSupported'
      str = sprintf('function %s is supported only for v%.1f or later.',varargin{1:2});
    case 'updateFirmware'
      str = 'Please run RTBoxCheckUpdate to update RTBox firmware.';
    otherwise
      str = sprintf('%s. GetSecs = %.1f', err, GetSecs);
  end
  str = WrapString(str);
  % warning(['RTBoxClass:' err],str);
  fprintf(2,'\n Warning: %s\n', str);
  fid = fopen('RTBoxWarningLog.txt', 'a');
  if fid<0, return; end
  fprintf(fid, '%s\n%s\n\n', datestr(now), str); % write warning into log file
  fclose(fid);
end

function purgeRTBox(p)
s = p.ser;
n = serIO('BytesAvailable', s);
tout = GetSecs+1; % if longer than 1s, something is wrong
while 1
    WaitSecs(p.latencyTimer+0.001); % allow buffer update
    n1 = serIO('BytesAvailable', s);
    if n1==n, break; end % not receiving
    if GetSecs>tout, RTBoxError('notRespond'); end
    n = n1;
end
serIO('Read', s);
end

function secs = bytes2secs(b6, ratio)
  % convert 6-byte b6 into box secs
  if nargin<2, ratio = 1; end
  secs = 256.^(5:-1:0) * b6 / 921600 * ratio;
end

function str = cell2str(Cstr)
  % return str from cellstr for printing, also remove port path
  if isempty(Cstr), str = ''; return; end
  str = Cstr;
  if ischar(str), str = cellstr(str);
  elseif isnumeric(str), str = cellstr(num2str(str));
  elseif isnumeric(str{1}), for i=1:numel(str), str{i}=num2str(str{i}); end
  end
  str = strrep(str, '\\.\', ''); % Windows path for ports
  str = strrep(str, '/dev/', '');  % MAC/Linux path for ports
  str = sprintf('%s, ', str{:}); % convert cell into str1, str2,
  str(end+(-1:0)) = ''; % delete last comma and space
end
