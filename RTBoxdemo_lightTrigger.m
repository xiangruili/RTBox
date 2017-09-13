function RTBoxdemo_lightTrigger(scrn)
% This is a demo showing how to generate a flash as light trigger,
% and use RTBox to measure reaction time.
% In this demo, the stimulus is random noise at the center of screen,
% and light trigger is a 1-frame flash at right edge. You need to mount the
% light sensor to the flash position for this to work.

% Xiangrui Li, 3/2008
% 170317 Remove dependency on RandSample()

if nargin<1, scrn = max(Screen('screens')); end % find last screen
nTrials = 10; % number of trials
timeout = 1; % timeout second for RT reading
trigsz = [80 80]; % trigger height and width
stimsz = 120; % stim square size
efactor = 3;  % larger noise checkers
stimdur = 0.2; % stimulus duration
trigsq = ones(trigsz)*255; % bright trigger square
csz = round(stimsz/efactor); % # of checkers
rnds = uint8(rand(stimsz^2*2,1)*255); % random noise stimulus
rt = nan(nTrials, 1);
RTBox('enable', 'light'); % enable light detection for trigger, also open device if needed

[w, res] = Screen('OpenWindow', scrn, 0); % open a dark screen
clnObj = onCleanup(@() sca);
ifi = Screen('GetFlipInterval', w); % flip interval

% print some instruction
Screen('TextSize', w, 24);
Screen('TextFont', w, 'Times');
str = 'This will measure your RT to noise square at the center of the screen.';
DrawFormattedText(w, str, 'center', res(4)*0.4, [255 0 0]);
str = sprintf(['We will do %d trials. When you see the noise, press a ' ...
    'button as soon as possible.'], nTrials);
DrawFormattedText(w, str, 'center', res(4)*0.45, [255 0 0]);
DrawFormattedText(w, 'Press any button to start', 'center', res(4)*0.55, 255);
Screen('Flip', w); % show instruction

trig_tex = Screen('MakeTexture', w, trigsq); % make trigger texture
% trigger position
% trigRect = [r(3)-trigsz(2)-10 50 r(3)-10 trigsz(1)+50]; % top-right
trigRect = [res(3)-trigsz(2)-10 res(4)/2-trigsz(1)/2 res(3)-10 res(4)/2+trigsz(1)/2]; % middle-right
% trigRect = [r(3)-trigsz(2)-10 r(4)-trigsz(1)-50 r(3)-10 r(4)-50]; % bottom-right

nFrame = round(stimdur/ifi);  % # of frames of stim
ClockRandSeed; % set random seed
tex = nan(1, nFrame);
n = numel(rnds);
for im = 1:nFrame % make stim textures for first trial
    stimsq = reshape(rnds(randi(n, csz)), [csz csz]);
    stimsq = Expand(stimsq, efactor);
    tex(im) = Screen('MakeTexture', w, stimsq);
end

Priority(MaxPriority(w));   % raise priority for better timing
RTBox(1000);  % wait 1000s, or till any enabled event
Screen('Flip', w); % remove instruction

for i = 1:nTrials
    WaitSecs(1+rand*3); % wait for 1 to 4 s randomly
    RTBox('clear', 0); % clear buffer before stim onset
    Screen('DrawTexture', w, tex(1)); % draw stim for 1st frame
    Screen('DrawTexture', w, trig_tex, [], trigRect); % draw trigger
    Screen('Flip', w); % show first frame: stim+trigger
    
    for im = 2:nFrame % draw noise for each frame
        Screen('DrawTexture', w, tex(im)); % draw frames
        Screen('Flip', w); % show stim, no trigger anymore
    end
    Screen('Flip', w); % turn off stim
    
    % prepare stim for next trial before reading RT
    Screen('Close', tex(:)); % release memory
    for im = 1:nFrame
        stimsq = reshape(rnds(randi(n, csz)), [csz csz]);
        stimsq = Expand(stimsq, efactor);
        tex(im) = Screen('MakeTexture', w, stimsq);
    end
    
    t = RTBox('light', timeout);  % read RT, relative to light trigger
    if isempty(t), continue; end % no response, skip it
    if numel(t)>1
        fprintf(' trial %2g: RT = ', i); fprintf('%8.4f', t); fprintf('\n');
        ind = find(t>0,1);  % find 1st proper rt in case of more than 1 response
        if isempty(ind), continue; end  % no reasonable response, skip it
        t = t(ind);
    end
    rt(i) = t;
end

Priority(0); % restore normal priority

% plot result
h = figure(1); set(h, 'color', [1 1 1]);
plot(rt, '+-');
set(gca, 'ylim', [0 0.4], 'box', 'off', 'tickdir', 'out');
ylabel('Response Time (s)'); xlabel('Trials');
rt(isnan(rt)) = []; % remove NaNs due to missed trials
feature('DefaultCharacterSet', 'UTF-8'); % needed for some matlab
str = sprintf('Your median RT: %.3f %s %.3f s', median(rt), char(177), std(rt));
title(str);
