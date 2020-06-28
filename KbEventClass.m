classdef KbEventClass < handle
  % This object-oriented code makes it easier to collect keypress response by
  % using KbQueueXXX and KbCheck.
  % 
  % Typical usage:
  %  kb = KbEventClass({'left' 'right'}); % start to queue 2 arrow keys
  %  t0 = kb.read('space'); % wait for space bar to start experiment
  %  for i = 1:nTrials
  %     % prepare stimulus for the trial
  %     kb.clear(); % clear possible residual response, since they are buffered
  %     onset = Screen('Flip', w); % stimulus on
  %     Screen('Flip', w, onset+stimDuration); % turn off stimulus
  %     [secs, keys] = kb.read(2); % wait up to 2 seconds for response
  %     if isempty(secs), continue; end % missed response
  %     if numel(secs)>1, secs = secs(end); keys = keys(end); end % 1+ response
  %     rt = secs(1) - onset; % response time
  %     % record response keys{1}, give feedback etc
  %  end
  %
  % Besides the above typical usage, another feature is to log all interested
  % keys and time during a session to detect/correct potential issue:
  %  kb = KbEventClass(); % queue 5 number keys (default)
  %  kb.flush(); % optionally empty the queue right before session start
  %  t0 = kb.read('5'); % suppose 5 is the trigger key to start the session
  %  for i = 1:nTrial
  %     kb.wait(designOnset-0.05); % not necessary, but allow ESC exit 
  %     onset = Screen('Flip', w, designOnset); % stim on at designed time
  %     kb.clear(); % do this right before or after stim onset of a trial
  %     [secs, keys] = kb.read(3, {'1' '2'}); % check subset of queued keys
  %  end
  %  [allSecs, allKeys] = kb.stop(); % get all press time/name since kb.flush()
  % 
  % Several static methods can be used with/without constructing the class
  % object. They use KbCheck(-1), so read keys from all connected keyboards:
  %  t = KbEventClass.check('esc'); % check if ESC is down NOW at any keyboard
  %  [t, key] = KbEventClass.wait({'a' 'b'}); % wait a/b keys press any keyboard
  %  KbEventClass.esc_exit(); % error out if ESC is down from any keyboard
  % If object is constructed with kb = KbEventClass(), it can also be used as:
  %  [t, key] = kb.check({'left' 'right'}); % work like PTB KbCheck(-1)
  %  t = kb.wait('space'); % work like PTB KbWait(-1)
  
  % 200428 wrote it, Xiangrui.Li at gmail.com
  % 200512 close to experiment quality
  
  properties
    deviceIndex % Device index used by PsychHID
    keyName % Key names to queue/read
  end
  properties(Hidden, SetAccess=private)
    keyCode % Key press code
    keyTime % Key press time
  end
  
  methods
    function this = KbEventClass(keys, productName)
      % Construct the object for later access, and start queue 
      %   kb = KbEventClass(keysToDetect, keyboardProductName);
      %
      % Default keys are numbers 1~5 at both main keyboard and number pad. To
      % get the name of a key, run KbEventClass.getName at Command Window.
      %
      % The second input is rarely needed, unless the code won't get your
      % keyboard correctly under OSX or Linux. Then you will need to input
      % either the index or product name of the keyboard.
      %
      % Example: kb = KbEventClass({'left' 'right'}); % 2 arrow keys
      
        if nargin<2, productName = []; end
        this.deviceIndex = productName;
        if nargin<1, keys = []; end
        this.keyName = keys;
        this.flush();
    end
          
    function start(this)
      % % Start the event queue (automatically called by constructor)
      %   kb.start(); % only needed if want to re-use the object after kb.stop()
        if isempty(this.keyName), return; end % called by setter
        try this.clear(); catch, end % in case constructor called again
        try KbQueueReserve(2, 1, this.deviceIndex); catch, end
        kCode = zeros(1, 256);
        kCode(ismemberi(this.getName('KeyNames'), this.keyName)) = 1;
        KbQueueCreate(this.deviceIndex, kCode);
        KbQueueStart(this.deviceIndex);
    end
        
    function [secs, keys] = clear(this, asked)
      % % Clear events in queue to avoid reading residual events. 
      %  kb.clear();
      % This does not affect the buffered events, while flush() does.
      % If output requested, this returns the time and keys of events in queue 
      %  [t, key] = kb.clear(); % return event since clear() or read()
      %  [t, key] = kb.clear({'1' '2'}); % return only subset of queued keys
        n = PsychHID('KbQueueFlush', this.deviceIndex, 0);
        secs = zeros(1, n); code = zeros(1, n, 'uint8'); j = 1;
        for i = 1:n
            evt = PsychHID('KbQueueGetEvent', this.deviceIndex);
            if evt.Pressed<1, continue; end % ignore non-press events
            secs(j) = evt.Time; code(j) = evt.Keycode; j = j + 1;
        end
        secs(j:n) = []; code(j:n) = [];
        if isempty(secs), keys = {}; return; end % not necessary
        this.keyTime = [this.keyTime secs];
        this.keyCode = [this.keyCode code]; % buffer events
        if nargout<1, return; end
        keys = this.getName(code);
        if nargin>1 && ~isempty(asked) % return only asked
            ind = ismemberi(keys, asked);
            secs = secs(ind); keys = keys(ind);
        end
    end
        
    function [secs, keys] = read(this, in1, in2)
      % % Read events in buffer (or wait events) since last clear() or read()
      %
      %  [secs, keys] = kb.read(secsToWait_or_keys);
      %
      % Return key press time and key names (cellstr). Both output will be empty
      % if there is no event.
      %
      % During the wait, pressing ESC will abort the code, so 'ESC' cannot be
      % used as a response key.
      %
      % The optional input can be the seconds to wait, the keys to detect (char,
      % string or cellstr), or both. For example:
      %       
      %  [t, key] = kb.read(1); % wait for 1 secs or a queued key is detected
      %  t = kb.read('space'); % wait till spacebar is pressed
      %  [t, key] = kb.read(3, {'1' '2'}); % wait keys 1 or 2 for up to 3 secs
      %
      % Note that the queued key will be reported even if it happened before the
      % read() call, while newly asked key can be detected only during the wait.
        
        if nargin == 1
            dur = inf; asked = [];
        elseif nargin == 2
            if isnumeric(in1), dur = in1(1); asked = [];
            else, dur = inf; asked = in1;
            end
        elseif nargin == 3
            if isnumeric(in1), dur = in1(1); asked = in2;
            else, dur = in2(1); asked = in1;
            end
        end
        
        endT = dur + GetSecs;
        oldKeys = this.keyName; % to compare later
        if ~isempty(asked)
            [secs, keys] = this.clear(asked); % check once before change keys
            if ~isempty(secs), return; end % have asked event: done
            this.keyName = [oldKeys asked]; % restart queue only if new keys
        end
        
        while 1 % check once even if time is up
            [secs, keys] = this.clear(asked);
            if ~isempty(secs) || this.esc_exit()>=endT, break; end
            WaitSecs('YieldSecs', 0.04); % due to queued, interval not critical
            if ispc, GetMouse; end % avoid busy cursor
        end
        if ~isequal(this.keyName, oldKeys), this.keyName = oldKeys; end % restore
    end
    
    function flush(this)
        % % Flush events in the buffer to start a new session
        KbQueueFlush(this.deviceIndex, 3); % both buffer
        % KbEventFlush(this.deviceIndex);
        this.keyCode = uint8([]); % save space by uint8
        this.keyTime = [];
    end
        
    function [secs, keys] = stop(this)
      % % Stop the queue, and return time and keys since flush() or queue start
      %  [secs, keys] = kb.stop(); 
        this.clear();
        KbQueueStop(this.deviceIndex);
        % KbQueueRelease(this.deviceIndex);
        if nargout, secs = this.keyTime; end
        if nargout>1, keys = this.getName(this.keyCode); end
    end
    
    function set.keyName(this, keys)
        if isempty(keys), keys = {'1' '2' '3' '4' '5'}; end
        if isnumeric(keys) && (any(keys<0) || any(keys>256))
            error('Invalid input for keys.');
        end
        keys = this.getName(keys); % sort by kcode, correct case
        % keys = unique(keys, 'stable');  % Octave has no 'stable' option
        [keys, i] = unique(keys, 'first'); % different kcode can have same name
        keys = keys(sort(i)); 
        if isequal(this.keyName, keys), return; end
        this.keyName = keys;
        this.start();
    end
    
    function set.deviceIndex(this, idx)
        if isempty(idx) || ~isnumeric(idx)
            idx = this.KbIndex(idx);
        end
        if this.deviceIndex == idx, return; end
        this.deviceIndex = idx;
        this.start();
    end
  end
  
  methods(Static)
    function idx = KbIndex(pName)
        % Return keyboard index used by PsychHID and KbQueueXXX functions.
        %   idx = KbEventClass.KbIndex(productName);
        %
        % If the keyboard product name is provided, this will try to find a
        % match. Otherwise it will try to find a known external keyboard for fRMI
        % setup, and use highest (Linux) or lowest (others) index as fallback.
        clear PsychHID; % refresh newly connected keyboard
        if ismac, d = PsychHID('Devices'); else, d = PsychHID('Devices', 4); end
        d = d([d.usagePageValue]==1 & [d.usageValue] == 6);
        if IsLinux, d = [d PsychHID('Devices', 2)]; end % as in KbCheck
        kbs = [d.index]; % linux may have repeats?
        product = {d.product};
        if numel(kbs)<2, idx = kbs; return; end % no choice, e.g. ispc
        if nargin<1 || isempty(pName)
            pName = {'932' 'fORP Interface' 'HIDKeys' 'Virtual'};
        elseif ischar(pName)
            pName = cellstr(pName);
        end
        for i = 1:numel(pName)
            for j = 1:numel(kbs)
                if ~isempty(regexpi(product{j}, pName{i}, 'once'))
                    idx = kbs(j); return;
                end
            end
        end
        if IsLinux, idx = kbs(end); else, idx = kbs(1); end % limited test
    end
    
    function [secs, keys] = check(asked)
      % % Check all keyboards, and return pressed time & key if any
      %  [secs, keys] = KbEventClass.check(); % check if any key is down
      %  secs = KbEventClass.check('space'); % check if spacebar is down
        [secs, kc] = KbCheck1();
        if ~any(kc), secs = []; keys = {}; return; end
        if nargin<1, asked = KbEventClass.getName('KeyNames'); end % any key
        keys = KbEventClass.getName(kc);
        keys = keys(ismemberi(keys, asked));
        if isempty(keys), secs = []; end
    end

    function [secs, keys] = wait(in1, in2)
      % % Wait till a time point or any asked key from all keyboard is pressed
      %   KbEventClass.wait(untilSecs); % wait till GetSecs reaches untilSecs
      %   secs = KbEventClass.wait('5'); % wait till key 5 press
      %   [secs, keys] = KbEventClass.wait(untilSecs, {'a' 'b'); % both input
        if nargin == 0
            endT = inf; asked = '';
        elseif nargin == 1
            if isnumeric(in1), endT = in1(1); asked = '';
            else, endT = inf; asked = in1;
            end
        elseif nargin == 2
            if isnumeric(in1), endT = in1(1); asked = in2;
            else, endT = in2(1); asked = in1;
            end
        end
    
        while 1
            [secs, keys] = KbEventClass.check(asked);
            if ~isempty(secs) || KbEventClass.esc_exit()>=endT, break; end
            WaitSecs('YieldSecs', 0.005);
            if ispc, GetMouse; end % trick to avoid busy mouse as in KbWait.m
        end
    end
    
    function secs = esc_exit()
        % Error out if ESC is detected from any keyboard
        %  KbEventClass.esc_exit();
        persistent esc
        if isempty(esc)
            esc = ismemberi(KbEventClass.getName('KeyNames'), 'esc'); 
        end
        [secs, kc] = KbCheck1();
        if any(kc(esc)), error('User pressed ESC. Exiting ...'); end
    end    
  
    function keys = getName(in)
        % Return simplified key names consistent acroos OS for shared keys
        %   keyName = KbEventClass.getName(arg);
        % If no input, it will wait for a key press and show the key name.
        % If arg is 'KeyNames', it will return all 256 names (some empty).
        % If arg is keyCode or index, it will return key names.
        % If arg is key names, it will sort them by keyCode and correct cases.
        persistent key256
        if isempty(key256), key256 = MapKeys(); end
        if nargin<1
            fprintf(' Press a key to show its name:\n');
            enter = ismemberi(key256, 'enter');
            while 1 % wait till return/enter key released
                [~, kc0] = KbCheck1();
                if ~any(kc0(enter)), break; end
                WaitSecs('YieldSecs', 0.01);
            end
            while 1 % wait for a newly pressed key
                [~, kc] = KbCheck1();
                kc(kc0>0) = 0; % in case of stuck keys
                if any(kc), break; end
                WaitSecs('YieldSecs', 0.01);
            end
            keys = key256(kc>0);
            if numel(keys)==1, keys = keys{1}; end
        elseif islogical(in)
            keys = key256(in);
        elseif isnumeric(in)
            if numel(in)==256 && ~(all(in>=1 & in<=256) && isequal(in, fix(in)))
                keys = key256(logical(in));
            else
                keys = key256(in);
            end
        elseif strcmpi(in, 'KeyNames')
            keys = key256;
        else % key names in char/string/cellstr
            keys = key256(ismemberi(key256, in));            
        end
    end   
  end
  
  methods(Hidden) 
    % Override inherited methods to hide them
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
    function delete(obj); delete@handle(obj); end
  end  
end

function Lia = ismemberi(A, B)
    % string version of ismember() and ignore case. Fast for small size(B). 
    if ischar(B), Lia = strcmpi(A, B); return; end
    Lia = strcmpi(A, B{1});
    for i = 2:numel(B)
        Lia = Lia | strcmpi(A, B{i});
    end
end

function [secs, kc] = KbCheck1()
% The same as KbCheck(-1), but avoid starting queue by PsychHID under Windows
    if ispc, [~, secs, kc] = Screen('GetMouseHelper', -1, [], -1); return; end
    [~, secs, kc] = KbCheck(-1); % -1 = all keyboards
end

function kk = MapKeys()
% Return all 256 key names (some empty) for the OS. This tries to use the same
% names for those keys shared by different OS, and won't distinguish number keys
% on main keyboard from keypad
% 200528 Adapted from old KeyName used by RTBox etc
kk = repmat({''}, [1 256]);
if ispc
    kk([1 2 4]) = {'left_mouse' 'right_mouse' 'middle_mouse'};
    kk([8 9 12 13 16:19 27 45:47]) = {'backspace' 'tab' 'clear' 'enter' ...
        'shift' 'control' 'alt' 'pause' 'esc' 'insert' 'delete' 'help'};
    kk([160:165 91:93]) = {'left_shift' 'right_shift' 'left_control' ...
        'right_control' 'left_alt' 'right_alt' 'left_menu' 'right_menu' 'application'};
    kk([32:40 44]) = {'space' 'pageup' 'pagedown' 'end' 'home' 'left' 'up' ...
        'right' 'down' 'printscreen'};
    kk(48:57) = cellstr(num2str((0:9)')); kk(96:105) = kk(48:57); % 0 to 9
    kk(65:90) = cellstr(char(97:122)'); % a to z
    kk(106:111) = {'*' '+' 'seperator' '-' '.' '/'};
    kk(112:135) = strtrim(cellstr(num2str((1:24)','f%g')));
    kk([20 144 145]) = {'capslock' 'numlock' 'scrolllock'};
    kk([186:192 219:222]) = {';' '=' ',' '-' '.' '/' '`' '[' '\' ']' char(39)};
elseif IsOSX
    kk(4:29) = cellstr(char(97:122)'); % a to z
    kk(30:39) = cellstr(num2str([1:9 0]'));
    kk(89:98) = kk(30:39);
    kk([99 101:103]) = {'.' 'application' 'power' '='};
    kk(40:44) = {'enter' 'esc' 'backspace' 'tab' 'space'};
    kk(45:57) = {'-' '=' '[' ']' '\' '#' ';' char(39) '`' ',' '.' '/' 'capslock'};
    kk([58:69 104:115]) = strtrim(cellstr(num2str((1:24)','f%g')));
    kk(70:82) = {'printscreen' 'scrolllock' 'pause' 'insert' 'home' 'pageup' ...
        'delete' 'end' 'pagedown' 'right' 'left' 'down' 'up'};
    kk(83:88) = {'numlock' '/' '*' '-' '+' 'enter'};
    kk(116:129) = {'execute' 'help' 'menu' 'select' 'stop' 'again' 'undo' ...
        'cut' 'copy' 'paste' 'find' 'mute' 'volumeup' 'volumedown'};
    kk(130:134) = {'capslock' 'numlock' 'scrolllock' ',' '='};                
    kk(155:159) = {'cancel' 'clear' 'prior' 'enter' 'seperator'};
    kk(224:231) = {'left_control' 'left_shift' 'left_alt' 'left_menu' ...
        'right_control' 'right_shift' 'right_alt' 'right_menu'};
elseif IsLinux
    kk([10 105:109 111:120 122:126 128]) = {'esc' 'enter' 'right_control' ...
        '/' 'printscreen' 'right_alt' 'home' 'up' 'pageup' 'left' 'right' ...
        'end' 'down' 'pagedown' 'insert' 'delete' 'mute' 'volumedown' ...
        'volumeup' 'power' '=' 'pause'};
    kk(134:136)= {'left_menu' 'right_menu' 'application'};
    kk([25:34 39:47 53:59]) = {'q' 'w' 'e' 'r' 't' 'y' 'u' 'i' 'o' 'p' 'a' ...
        's' 'd' 'f' 'g' 'h' 'j' 'k' 'l' 'z' 'x' 'c' 'v' 'b' 'n' 'm'};
    kk([20 11:19]) = cellstr(num2str((0:9)'));
    kk([68:77 96:97]) = strtrim(cellstr(num2str((1:12)','f%g')));
    kk(78:92)={'numlock' 'scrolllock' '7' '8' '9' '-' '4' '5' ...
        '6' '+' '1' '2' '3' '0' '.'};
    kk([21:24 35:38 48:52 60:67]) = {'-' '=' 'backspace' 'tab' '[' ']' ...
        'enter' 'left_control' ';' '''' '`' 'left_shift' '\' ',' '.' '/' ...
        'right_shift' '*' 'left_alt' 'space' 'capslock'};
elseif IsOS9 % not tested, and probably useless 
    kk([1 12 9 3 15 4 6 5 35 39 41 38 47 46 32 36 13 16 2 18 33 10 14 8 17 7]) ...
        = cellstr(char(97:122)'); % a to z
    kk([83:90 92 93]) = cellstr(num2str((0:9)'));
    kk([30 19 20:22 24 23 27 29 26]) = kk([83:90 92 93]);
    kk([123 121 100 119 97:99 101 102 110 104 112 106 108 114]) ...
        = strtrim(cellstr(num2str((1:15)','f%g')));
    kk([52 49 72 37 54 58]) = {'delete' 'tab' 'clear' 'enter' 'esc' 'capslock'};
    kk([57 60 59 56 77 115 118]) = {'left_shift' 'left_control' 'left_alt' ...
        'left_gui' 'enter' 'help' 'delete'};
    kk([50 117 122 120 116 124:127]) = {'space' 'pageup' 'pagedown' 'end' ...
        'home' 'left' 'right' 'down' 'up'};
    kk([25 28 34 31 40 42:45 48 51 66 68 70 76 79 82]) = {'=' '-' '[' ']' ...
        char(39) ';' '\' ',' '/' '.' '`' '.' '*' '+' '/' '-' '='};
else
    error('Unsupported Platform: %s.', computer);
end
end
