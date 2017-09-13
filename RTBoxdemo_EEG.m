% This is a demo showing how to use RTBox as EEG interface.
% The idea is to mark the onset of stimulus in EEG data by sending a TTL.
% The task is to identify the orientation of gabor. If gabor tilts to 11
% o'clock, press a left button; if to 1 o'clock, press a right button.
% The result will be displayed in command window.

% Xiangrui Li, 3/2009

function RTBoxdemo_EEG(scrn)
if nargin<1, scrn = max(Screen('screens')); end % find last screen

radius = 3;   % gabor radius in degree
dAngle = 5; % tilt degree from vertical
sf = 1.5; % spatial freq: cycles per deg
stimDur = 0.1; % stimulus duration in sec
trialDur = 2;    % length of trial
ppd  =42; % pixels per degree: depending on distance, screen size and resolution
% ppd=distance*tan(1/180*pi)/screenWidth*screnResX;
contrast = [0.05 0.2 0.8]; % gabor contrast
nCond = numel(contrast);
trialsPerCond = 6; % # of trials per condition, even number
nTrials = trialsPerCond*nCond;  % # of trials
randSeed = ClockRandSeed; % set seed for rand and randn

% record contains stim info and response.
% We assign NaN to missed and unreasonable response.
record = nan(nTrials,7);
%columns:  iTrial cond tiltRight respCorrect RT trialStartSecs dt
recLabel = 'trial cond tiltRight respCorrect respTime startSecs dt';
record(:,1) = 1:nTrials; % # of trial
seq = repmat(1:nCond, trialsPerCond, 1); % condition numbers
LR = ones(size(seq));
LR(1:trialsPerCond/2,:) = 0; % tiltRight: half ones, half zeros
[record(:,2), ind] = Shuffle(seq(:)); % radomize condition numbers
record(:,3) = LR(ind); % use the same order so half of each condition tilt left

% RTBox('fake',1); % set RTBox to fake mode: use keyboard to simulate
RTBox('UntilTimeout', false); % Open RT box if hasn't
RTBox('ButtonNames', {'left' 'left' 'right' 'right'}); % make first 2 and last 2 equivalent

[w, r] = Screen('OpenWindow', scrn, 127); % open a screen
clnObj = onCleanup(@() sca);
HideCursor;
hz = FrameRate(w);

% print some instruction
Screen('TextSize', w, round(24/r(4)*1024)); % proportional font size
Screen('TextFont', w, 'Times'); % seems needed for Windows
str = sprintf(['This will test your RT to gabor orientation identification.\n' ...
    'We will do %d trials. When you see a tilted gabor:\n'...
    'press 1st or 2nd button if it tilts to left,\n' ...
    'press 3rd or 4th button if it tilts to right.\n\n' ...
    'Press any button to start.'], nTrials);
DrawFormattedText(w, str, 'center', 'center', 255, [], 0, 0, 1.5);
Screen('Flip', w); % show instruction

txtsz = Screen('Textbounds', w, 'M');
ycenter = round(r(4)/2-txtsz(4)/2); % vertical center for feedback

% generate texture tilted to left, will rotate 2*dAngle to tilt right
imgsz = round(radius*ppd*2); % image size in pixels
rect = CenterRect([0 0 1 1]*imgsz, r); % stim rect
[x, y] = meshgrid(linspace(-radius, radius, imgsz)); % symmetric coordinates
mask = exp(-(x.^2 + y.^2) / (radius/2)^2);  % gaussian mask: 0 to 1
img = sind(360*sf*(x*cosd(-dAngle)+y*sind(-dAngle))); % grating tilted left from vertical
img = img .* mask; % apply mask
for i = 1:nCond
    img0 = img * contrast(i); % apply contrast
    img0 = round((img0+1)*127); % convert from [-1 1] to [0 254]
    tex(i) = Screen('MakeTexture',w,img0); %#ok texture
    Screen('FrameOval', tex(i), 140, [0 0 imgsz imgsz]); % circle
end
clear x y mask img img0; % later, we need texture only

Priority(MaxPriority(w));   % raise priority for better timing
RTBox(inf); % wait for any button press
t0 = RTBox('TTL',nCond+1); % mark the beginning of a run
tStr = datestr(now); % for record
Screen('FrameOval', w, 140, rect); % circle
vbl = Screen('Flip', w);  % turn off instruction

stimDur = (round(stimDur*hz)-0.5)/hz; % half refresh interval shorter

for i = 1:nTrials
    cond = record(i,2); % contrast index for this trial
    angl = dAngle * record(i,3) * 2; % 0 or dAngle*2 in deg
    Screen('DrawTexture', w, tex(cond), [], rect, angl); % draw to buffer
    Screen('DrawingFinished', w);
    
    WaitTill(vbl+trialDur+rand);  % wait some time bewteen trials
    RTBox('clear');   % clear right before stimulus onset
    vbl = Screen('Flip', w);  % show stim, return onset time
    t_onset = RTBox('TTL', cond); % mark stim onset with condition number immediately after Flip
    Screen('FrameOval', w, 140, rect); % circle
    Screen('Flip', w, vbl+stimDur); % turn off stim and show circle
    Screen('FrameOval', w, 140, rect); % circle
    
    record(i,6) = vbl-t0;  % stim start secs
    record(i,7) = t_onset-vbl;  % diff between vbl and TTL: TTL delay relative to Flip
    
    [t, btn] = RTBox(trialDur-0.2); % return computer time and button
    
    % check response
    str = 'Missed';
    if ~isempty(t)
        t = t-vbl; % RT now
        if numel(t)>1 % more than 1 response
            fprintf(' #trial %2g: RT=', i);
            fprintf('%8.4f', t); fprintf('\n');
            ind = find(t>0.1, 1); % find the 1st proper rt
            % you may set your criterion, for example t>0.2
            if isempty(ind), continue; end  % no reasonable response, skip trial
            t = t(ind); btn = btn{ind}; % use the first reasonable response
        end
        
        % record correctness and RT
        correct = record(i,3) == strcmp(btn, 'right');
        record(i, 4:5) = [correct t];
        
        % feedback
        if correct, str = 'Correct'; else str = 'Wrong'; end
    end
    DrawFormattedText(w, str, 'center', ycenter, 0);
    Screen('Flip', w);
end
WaitTill(vbl+trialDur);
Priority(0);      % restore normal priority

% save myresult record t0 randSeed;  % save a MAT file

% display or save result
fid = 1; % display in command window
% fid = fopen('myresult.txt','w+'); % you should save result in a file
fprintf(fid, 'randSeed = %d\n', randSeed);
fprintf(fid, 't0 = %.4f\n', t0); % start time. Useful with RTBoxWarningLog.txt
fprintf(fid, 'Started at %s\n\n', tStr);
fprintf(fid, ' %s\n', recLabel);
fprintf(fid, '%6g %4g %9g %11g %8.4f %9.4f %9.4f\n', record'); % one trial per row
fprintf(fid, '\nFinished at %s\n', datestr(now));
fclose('all'); % no complain for fid=1
