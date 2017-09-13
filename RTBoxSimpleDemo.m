function RTBoxSimpleDemo(scrn)
% This is a demo showing how to use RTBox at simple mode. 
% Run the program. When you see noise square at the center of screen, press
% a button. Your RT will be plotted after the assigned number of trials.

% Xiangrui Li, 04/2011
   
if nargin<1, scrn=max(Screen('screens')); end % find last screen
nTrials = 10;  % # of trials
sz = 64; % noise square size in pixels
secs = 1; % time to show noise
rt = nan(nTrials, 1);
RTBoxSimple('clear');  % in case it has not been initialized

[w, rect]=Screen('OpenWindow',scrn,127);  % open screen
clnObj = onCleanup(@() sca);
HideCursor;

% print some instruction
Screen('TextSize', w, 24); 
Screen('TextFont', w, 'Times');
str = 'This will test your response time to a noise square at the center of the screen.';
DrawFormattedText(w, str, 'center', rect(4)*0.4, [255 0 0]);
str = sprintf('We will do %d trials. When you see a flash, press a button as soon as possible.', nTrials);
DrawFormattedText(w, str, 'center', rect(4)*0.45, [255 0 0]);
DrawFormattedText(w, 'Press any button to start', 'center', rect(4)*0.55, 255);
Screen('Flip', w); % show instruction

Priority(MaxPriority(w));   % raise priority for better timing
while 1 % wait till any enabled event
    if RTBoxSimple('EventsAvailable'), break; end
end
Screen('Flip', w);  % turn off instruction

img = (randn(sz)/6+0.5)*254; %#ok
[b, t] = RTBoxSimple('read'); %#ok practice it

for i = 1:nTrials
    tout = WaitSecs(1+rand*2) + secs; % random interval for subject
    
    t0 = [];
    RTBoxSimple('clear'); % clear buffer
    while GetSecs<tout
        img = (randn(sz)/6+0.5)*254;
        Screen('PutImage', w, img);
        vbl = Screen('Flip', w);  % show stim
        if isempty(t0), t0 = vbl; end
        [~, t] = RTBoxSimple('read');
        if ~isempty(t), break; end
    end
    Screen('Flip', w); % turn off stim
    
    if ~isempty(t), rt(i) = t-t0; end % record the RT
end

Priority(0); % restore normal priority

% plot result
h = figure(9); set(h, 'color', [1 1 1]); 
plot(rt, '+-');
set(gca, 'box', 'off', 'tickdir', 'out');
ylabel('Response Time (s)'); xlabel('Trials');
rt(isnan(rt)) = []; % remove NaNs due to missed trials
feature('DefaultCharacterSet', 'UTF-8'); % needed for some matlab
str = sprintf('Your median RT: %.3f %s %.3f s', median(rt), char(177), std(rt));
title(str);
