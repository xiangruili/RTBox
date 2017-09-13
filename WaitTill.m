% [key, secs] = WaitTill (tillSecs);
% - Wait till GetSecs clock reaches tillSecs. It is similar to
% WaitSecs('UntilTime', tillSecs), but optionally, it returns the first
% pressed keys during the wait and key press time.
% 
% [key, secs] = WaitTill (KEYS);
% - Wait till any key defined in KEYS is pressed. This is similar to
% KbWait, but it waits only defined keys, and optionaly returns key and key
% press time. KEYS can be a string for a key name, or cell string for
% multiple key names. This will detect only keys in KEYS, so provide a way
% to ignore other keys, such as the stuck keys in some computers and the TR
% trigger 'key' from MRI scanner. To detect any key, pass '' for KEYS.
% WaitTill uses consistent name across Windows, MAC and Linux for the keys
% they share. To get list of key names, use next command. 
% 
% allKeys = WaitTill('KeyNames');
% - Return all key names (sorted) for your system.
% 
% [key, secs] = WaitTill (tillSecs, KEYS [, keyReturn=1]);
% [key, secs] = WaitTill (KEYS, tillSecs [, keyReturn=1]);
% - Wait till either tillSecs reaches or a key in KEYS is pressed. Return
% the first pressed keys, or empty if none, and time. The optional third
% argument, default ture, tells whether the function will return when a key 
% is detected. If it is false, the function will wait till tillSecs even if
% a key is detected.
% 
% - In case more than one keys in KEYS are pressed simultaneously, all of
% them will be returned in key as a cellstr, as by ReadKey. It is your
% responsibility to deal with this special case by yourself. For example,
% you could deal with different number of keys like this: 
% 
% if isempty(key), continue; % no key press, continue next trial in a loop
% elseif iscellstr(key), key = key{1}; % more than one key, take the 1st?
% end
% 
% - In any case, ESC will abort execution unless 'esc' is included in KEYS.
% 
% See also ReadKey KbCheck

% xl, 04/2006, wrote it
% xl, 02/2009, made syntax more flexible
% xl, 05/2009, added fORP global
% xl, 06/2009, added multi-key detection, acutually in ReadKey.m
% xl, 10/2010, use WaitSecs('YieldSecs',0.001) for all systems and fORP is
%               removed since it is not needed anymore

function varargout = WaitTill (varargin)
switch nargin
    case 0, help(mfilename); return;
    case 1
        if isnumeric(varargin{1})
            tillSecs = varargin{1}; 
            keys = ''; 
            keyReturn = 0;
        else
            tillSecs = inf; 
            keys = varargin{1}; 
            keyReturn = 1;
        end
    case 2
        if isnumeric(varargin{1}), tillSecs = varargin{1}; keys = varargin{2};
        else, tillSecs = varargin{2}; keys = varargin{1};
        end
        keyReturn = 1;
    case 3
        if isnumeric(varargin{1}), tillSecs = varargin{1}; keys = varargin{2};
        else, tillSecs = varargin{2}; keys = varargin{1};
        end
        keyReturn = varargin{3};
    otherwise, error('Too many input arguments.');
end
if isempty(tillSecs), tillSecs = inf; end
key = ''; secs = tillSecs;
while 1
    [kk, tnow] = ReadKey(keys);
    if ~isempty(kk) && isempty(key)
        key = kk; secs = tnow; 
        if keyReturn, break; end
    end
    if tnow>tillSecs, break; end
    if tillSecs-tnow>0.1, WaitSecs('YieldSecs', 0.001); end
end
if nargout, varargout = {key, secs}; end
