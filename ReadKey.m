% [key, secs] = ReadKey [(KEYS)];
% Return pressed key, or empty if no key pressed. secs is the time
% returned by KbCheck. ESC will abort execution unless it is in KEYS.
% 
% If optional input KEYS, {'left' 'right'} for example, is provided, only
% provided KEYS will be detected. 
% 
% The key names are consistent across systems if they are shared. This
% won't distinguish keys on number pad from those number keys on main
% keyboard. To get all key names on your system, use ReadKey('KeyNames').
% 
% This runs fast after first call, so it is safe to call within each video
% frame. 
% 
% See also WaitTill, KbCheck

% 09/2005 wrote it (Xiangrui Li)
% 06/2009 added multi-key detection
% 06/2009 make it compatible to PTB 2 and 3
% 05/2011 add CharAvail to take case of fOPR problem
% 08/2012 call ListenChar for exit in case ListenChar(2) was called
% 04/2013 remove GetChar, CharAvail and ListenChar. One reason is we don't
%         use fORP USB anymore, and the other is its conflict with KbQueue.

function [key, secs] = ReadKey (KEYS)
persistent isPTB2;
if isempty(isPTB2)
    os = Screen('Computer'); % rely on PTB2 has no osx field
    isPTB2 = ~isfield(os, 'osx');
end
if nargin<1, KEYS = ''; end
if ischar(KEYS) && strcmpi(KEYS, 'KeyNames')
    key = KeyName(KEYS); secs = GetSecs; return;
end
key = '';
if isPTB2, [keyIsDown, secs, keyCode] = KbCheck; % for PTB2
else, [keyIsDown, secs, keyCode] = KbCheck(-1); % all devices for MAC
end
if keyIsDown
    keys = KeyName(keyCode);
    KEYS = lower(KEYS);
    if any(strcmpi(keys, 'esc')) && ~any(strcmp('esc', KEYS))
        Priority(0); fclose('all'); sca;
        error('User pressed ESC. EXITING.'); 
    end
    if isempty(KEYS); key = keys; return; end % return all detected keys
    for i = 1:numel(keys)
        if any(strcmp(keys{i}, KEYS))
            key{end+1} = keys{i}; %#ok
        end
    end
    if numel(key)==1, key = key{1}; end
end

% key = KeyName(keyCode); 
% Return key names from key codes. keyCode can be those returned by KbCheck
% (it is a pity that it is not logical, but double for historical reason.),
% logicals or doubles of any length. The returned key name is a cellstr.
% 
% keyCodes = KeyName(keyNames); 
% Return key codes for key names. keyNames can be a single key name, or a
% cellstr containing multiple key names. The returned code is double array,
% one value for each key name.
% 
% allKeyNames = KeyName('KeyNames'); 
% Return all key names for your system. 
% 
% This is simplified from KbName. The possbile advantages are: (1) it takes
% shorter time than KbName in PTB2 after first evokation. (2) it won't
% distinguish numbers at keypad from those on main keyboard. (3) it makes
% key names consistent across different systems for those shared keys.
% 
% This is mainly called by ReadKey, although you can use it in the similar
% was to KbName.

% 09/2005, wrote it (xiangrui.li@gmail.com)
% 06/2009, make it compatible to PTB2 and 3
% 06/2009, return all key name, not by ReadKey anymore
% 04/2013, add 'MACI64' according to Yuki
% 11/2014, take care of computer output for Octave

function out = KeyName(in)
persistent kk % faster for later call
if isempty(kk), kk = MapKeys; end
if isnumeric(in)
    if numel(in)==256 && max(in)==1 % returned from KbCheck
        in = logical(in); 
    end
    out = kk(in);
elseif islogical(in)
    out = kk(in);
else
    in = lower(in);
    if ischar(in)
        if strcmpi(in, 'keynames'), out = unique(kk(true(256,1))); return; end
        in = cellstr(in); 
    end
    for i = 1:numel(in)
        out(i) = find(strcmpi(in{i}, kk), 1); %#ok
    end 
end

function kk = MapKeys
kk = repmat({'undefined'},[256 1]);
c = computer;
if exist('OCTAVE_VERSION', 'builtin')
   if ~isempty(strfind(c, 'linux-gnu')),  c = 'GLNXA64'; %#ok<*STREMP>
   elseif ~isempty(strfind(c, 'apple-darwin')), c = 'MACI64';
   else, c = 'PCWIN64';
   end
end

switch c
    case {'PCWIN' 'PCWIN64'} % Windows
        kk([1 2 4]) = {'left_mouse' 'right_mouse' 'middle_mouse'}; % PTB 3 not detect mouse
        kk([8 9 12 13 19 27 45 46]) = {'backspace' 'tab' 'clear' 'return' 'pause' 'esc' 'insert' 'delete'};
        kk([160:163 18 91 92]) = {'left_shift' 'right_shift' 'left_control' 'right_control' 'alt' 'left_menu' 'right_menu'};
        kk([32:40 44]) = {'space' 'pageup' 'pagedown' 'end' 'home' 'left' 'up' 'right' 'down' 'printscreen'};
        kk(48:57) = cellstr(num2str((0:9)'));  
        kk(96:105) = kk(48:57); % 0 to 9
        kk(65:90) = cellstr(char(97:122)'); % a to z
        kk(106:111) = {'*' '+' 'seperator' '-' '.' '/'};
        kk(112:135) = strtrim(cellstr(num2str((1:24)','f%g')));
        kk([20 144 145]) = {'capslock' 'numlock' 'scrolllock'};
        kk([186:192 219:222]) = {';' '=' ',' '-' '.' '/' '`' '[' '\' ']' char(39)};
    case {'MAC' 'MACI' 'MACI64'} % OS X
        kk(4:29) = cellstr(char(97:122)'); % a to z
        kk(30:38) = cellstr(num2str((1:9)')); kk{39} = '0';
        kk(89:98) = kk(30:39);
        kk([99 103]) = {'.' '='};
        kk(40:44) = {'return' 'esc' 'delete' 'tab' 'space'};
        kk(45:57) = {'-' '=' '[' ']' '\' '#' ';' char(39) '`' ',' '.' '/' 'capslock'};
        kk([58:69 104:115]) = strtrim(cellstr(num2str((1:24)','f%g')));
        kk(70:82) = {'printscreen' 'scrolllock' 'pause' 'insert' 'home' 'pageup' 'delete' 'end' 'pagedown' 'right' 'left' 'down' 'up'};
        kk(83:88) = {'clear' '/' '*' '-' '+' 'enter'};
        kk(155:159) = {'cancel' 'clear' 'prior' 'return' 'seperator'};
        kk(224:231) = {'left_control' 'left_shift' 'left_alt' 'left_gui' 'right_control' 'right_shift' 'right_alt' 'right_gui'};
    case 'MAC2' % OS 9
        kk([1 12 9 3 15 4 6 5 35 39 41 38 47 46 32 36 13 16 2 18 33 10 14 8 17 7]) = cellstr(char(97:122)'); % a to z
        kk([83:90 92 93]) = cellstr(num2str((0:9)'));
        kk([30 19 20:22 24 23 27 29 26]) = kk([83:90 92 93]);
        kk([123 121 100 119 97:99 101 102 110 104 112 106 108 114]) = strtrim(cellstr(num2str((1:15)','f%g')));
        kk([52 49 72 37 54 58]) = {'delete' 'tab' 'clear' 'return' 'esc' 'capslock'};
        kk([57 60 59 56 77 115 118]) = {'left_shift' 'left_control' 'left_alt' 'left_gui' 'enter' 'help' 'delete'};
        kk([50 117 122 120 116 124:127]) = {'space' 'pageup' 'pagedown' 'end' 'home' 'left' 'right' 'down' 'up'};
        kk([25 28 34 31 40 42:45 48 51 66 68 70 76 79 82]) = {'=' '-' '[' ']' char(39) ';' '\' ',' '/' '.' '`' '.' '*' '+' '/' '-' '='};
    case {'GLNX86' 'GLNXA64' 'GLNXI64'} % linux
        kk([10 98:101 103:114 127]) = {'esc' 'home' 'up' 'home' 'left' 'right' 'end' 'down' 'pagedown' 'insert' 'delete' 'enter' 'right_control' 'pause' 'print' '/' 'right_alt' '='};
        kk([25:34 39:47 53:59]) = {'q' 'w' 'e' 'r' 't' 'y' 'u' 'i' 'o' 'p' 'a' 's' 'd' 'f' 'g' 'h' 'j' 'k' 'l' 'z' 'x' 'c' 'v' 'b' 'n' 'm'};
        kk([20 11:19]) = cellstr(num2str((0:9)'));
        kk([68:77 96:97]) = strtrim(cellstr(num2str((1:12)','f%g')));
        kk([91 88:90 84:86 80:82]) = kk([20 11:19]);
        kk([78:79 83 87 92]) = {'numlock' 'scrolllock' '-' '+' 'delete'};
        kk([21:24 35:38 48:52 60:67]) = {'-' '=' 'backspace' 'tab' '[' ']' 'return' 'left_control' ';' '''' '`' 'left_shift' '\' ',' '.' '/' 'right_shift' '*' 'left_alt' 'space' 'capslock'};
    otherwise, error('Unsupported Platform.');
end
