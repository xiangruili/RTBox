function RTBoxdemo(scrn)
% This is a demo showing how to measure reaction time using RTBox.
% Run the program. When you see flash on screen, press a button.
% Your RT will be plotted after the assigned number of trials.
% Xiangrui Li, 3/2008
% 160909 Add more comment

if nargin<1, scrn = max(Screen('screens')); end % find last screen
nTrials =10; % number of trials
timeout = 1; % timeout for RT reading
sq = [0 0 100 100]; % square size of the stimulus
rt = nan(nTrials, 1); % pre-allocate response time

% RTBox('fake', 1); % keyboard simulate button box
% This is useful to test code without RTBox hardware connected to the computer.
% The limitation is that the RTBox button names must be valid key names.

RTBox('clear');  % in case it has not been initialized

% RTBox('enable','light'); % enable light detection
% If you attach the light sensor to location of flash at the screen, the light
% signal will simulate button press. The measured response time will be the
% delay between Screen('Flip') and light flash.

[w, res] = Screen('OpenWindow', scrn, 0); % open a dark screen
clnObj = onCleanup(@() sca); % close screen when done, or in case of error
sq = CenterRect(sq, res);
HideCursor;
ifi = Screen('GetFlipInterval', w); % flip interval

% print some instruction
Screen('TextSize', w, 24);
Screen('TextFont', w, 'Times');
str = 'This will test your response time to flash at the center of the screen.';
DrawFormattedText(w, str, 'center', res(4)*0.4, [255 0 0]);
str = sprintf(['We will do %d trials. When you see a flash, ' ...
    'press a button as soon as possible.'], nTrials);
DrawFormattedText(w, str, 'center', res(4)*0.45, [255 0 0]);
DrawFormattedText(w, 'Press any button to start', 'center', res(4)*0.55, 255);
Screen('Flip', w); % show instruction

Priority(MaxPriority(w)); % raise priority for better timing
RTBox(1000);  % wait 1000 s, or till any enabled event
vbl = Screen('Flip',w);  %#ok turn off instruction

for i = 1:nTrials
    WaitSecs(1+rand); % random interval for subject
    Screen('FillRect', w, 255, sq);
    RTBox('clear'); % clear buffer and sync clocks before stimulus onset
    vbl = Screen('Flip',w);  % show stim, return stim start time
    Screen('Flip', w, vbl+ifi*1.5); % turn off square after 2 frames
    
    % here you can prepare stim for next trial before you read RT
    t = RTBox(timeout); % GetSecs time of button response
    
    % check response
    if isempty(t), continue; end % no response, nan in the data
    t = t - vbl; %  response time
    if numel(t) > 1 % more than 1 response
        fprintf(2, ' trial %2g: RT = ', i); fprintf('%8.4f', t); fprintf('\n');
        ind = find(t>0,1); % use 1st proper rt in case of more than 1 response
        if isempty(ind), continue; end  % no reasonable response, skip it
        t = t(ind);
    end
    rt(i) = t; % record the RT
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
