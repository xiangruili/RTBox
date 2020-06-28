function [key, secs] = ReadKey (KEYS)
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

% 09/2005 wrote it (Xiangrui Li)
% 06/2009 added multi-key detection
% 200608 call KbEventClass, keep this only for compatibility

if nargin<1, KEYS = KbEventClass.getName('KeyNames'); end
if ischar(KEYS) && strcmpi(KEYS, 'KeyNames')
    key = KbEventClass.getName(KEYS); secs = GetSecs; return;
end
[secs, key] = KbEventClass.check(KEYS);
if isempty(key), key = ''; secs = GetSecs; return; end
if ~ismember('esc', KEYS), KbEventClass.esc_exit(); end
if numel(key)==1, key = key{1}; end
