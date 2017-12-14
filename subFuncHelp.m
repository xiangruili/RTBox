function subFuncHelp(mfile, cmd)
% subFuncHelp('mfilename', 'cmd')
% 
% Show help text for a cmd of function, using the same syntax as most PTB
% function.
% 
% For example, to get help for cmd 'Open' of PsychRTBox, you can type PsychRTBox
% open? or PsychRTBox('open?').
%
% For this to work, in the m code, your cmd can't contain '?', and you need to
% insert the following line at the beginning of the code.
%
%  if any(cmd=='?'), subFuncHelp(mfilename, cmd); return; end
% 
% Also, this requires some special format for the help text. The help text for
% each command must start with mfilename('cmd') line(s), be followed by ' - '
% line, and end with a blank line. Here is some detail:
% 
%  1. The syntax line must have at least one blank line before it. If there are
%     multiple syntax lines, there must be no blank lines between them.
%  2. The followed explanation line(s) must start with a line starting with
%     characters '% - ' or '% -- '. This means the first line must start with a
%     percent sign as other help lines do, and be followed by a space, one or
%     two minus signs, and another space.
% 
% For example, the help text for commmand 'open' in function myFunc.m can be
% something like this:
% 
% out = myFunc('open', para)
% 
% - Here is the help text for 'open' command. Notice the minus sign and space
% before and after it. There must be at least one blank line(s) before next
% syntax line.

% 101001 Polished from a version long time ago for RTBox.m (XL)
% 110701 simplify two space detection and some bug fix
% 141101 add read help for Octave
% 150102 almost rewrite to make it more reliable
% 170909 Make it much simpler by using regexp, and hope more reliable

fname = which(mfile);
[pth, nam, ext] = fileparts(fname);
if ~strcmpi(ext, '.m') && ~strcmpi(ext, '.p')
    fname = fullfile(pth, [nam '.m']);
end
str = fileread(fname);
i = regexp(str, '\n\s*%', 'once'); % start of 1st % line
str = regexp(str(i:end), '.*?(?=\n\s*[^%])', 'match', 'once'); % help text
str = regexprep(str, '\r?\n\s*%', '\n'); % remove '\r' and leading %

dashes = regexp(str, '\n\s*-{1,4}\s+') + 1; % lines starting with 1 to 4 -
if isempty(dashes), disp(str); return; end % Show all help text

prgrfs = regexp(str, '(\n\s*){2,}'); % blank lines
nTopic = numel(dashes);
topics = ones(1, nTopic+1);
for i = 1:nTopic
    ind = regexpi(str(1:dashes(i)), [mfile '\s*\(']); % syntax before ' - '
    if isempty(ind), continue; end % no syntax before ' - ', assume start with 1
    ind = find(prgrfs < ind(end), 1, 'last'); % previous paragraph
    if isempty(ind), continue; end
    topics(i) = prgrfs(ind) + 1; % start of this topic 
end
topics(end) = numel(str); % end of last topic

cmd = strrep(cmd, '?', ''); % remove ? in case it is in subcmd
if isempty(cmd) % help for main function
    disp(str(1:topics(1))); % subfunction list before first topic
    return;
end

expr = [mfile '\s*\(\s*''' cmd ''''];
for i = 1:nTopic
    if isempty(regexpi(str(topics(i):dashes(i)), expr, 'once')), continue; end
    disp(str(topics(i):topics(i+1)));
    return;
end

fprintf(2, ' Unknown command for %s: %s\n', mfile, cmd); % no cmd found
