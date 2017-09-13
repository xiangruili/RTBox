% This is a demo showing how to use RTBox as EEG+fMRI interface.
% The task is to identify the orientation of gabor. If gabor tilts to 11
% o'clock, press a left button; if to 1 o'clock, press a right button.
% The result will be displayed in command window.
% Xiangrui Li, 3/2009

function varargout = RTBoxdemo_EEGfMRI(scrn)
if nargin<1, scrn=max(Screen('screens')); end % find last screen
radius = 3;   % gabor radius in degree
dAngle = 5; % tilt degree from vertical
sf = 1.5; % spatial freq: cycles per deg
lagg = 5; % time for lead in and lead out
trialDur = 4; % here we use fixed trial duration
stimDur = 0.1; % stimulus duration in sec
ppd = 42; % pixels per degree: depending on distance, screen size and resolution
% ppd=distance*tan(1/180*pi)/screenWidth*screnResX;
contrast = [0.05 0.2 0.8]; % gabor contrast
ncond = numel(contrast);
trialsPerCond = 5; % # of trials per condition
nTrials = trialsPerCond*ncond;  % # of trials

runSecs = trialDur*nTrials + lagg*2;
if nargout, varargout = {runSecs}; return; end % return runSecs if output provided
randSeed = ClockRandSeed; % set seed for rand and randn

% record contains stim info and response.
% We assign NaN to missed and unreasonable response
record = nan(nTrials,6);
%columns: iTrial cond tiltRight respCorrect RT FlipSes TTLSecs-FlipSes
recLabel = 'trial cond tiltRight respCorrect respTime startSecs dt';
record(:,1) = 1:nTrials; % # of trial
seq = ones(nTrials,1);
for i = 2:ncond
    seq(trialsPerCond*(i-1)+(1:trialsPerCond)) = i;
end
seq = Shuffle(seq); % you may use other better method for random seq
record(:,2) = seq; %
LR = ones(nTrials, 1);
LR(1:round(nTrials/2)) = 0; % half ones, half zeros
record(:,3) = Shuffle(LR); % 1 for tilt right, 0 left

% RTBox('fake',1); % set RTBox to fake mode: use keyboard to simulate
RTBox('UntilTimeout', 1); % for timed trials, this is better
RTBox('ButtonNames', {'left' 'left' 'right' 'right'}); % make first 2 and last 2 equivalent

[w, r] = Screen('OpenWindow', scrn, 127);  % open a screen
clnObj = onCleanup(@() sca);
HideCursor;
ifi = Screen('GetFlipInterval', w); % flip interval

% print some instruction
Screen('TextSize', w, round(24/r(4)*1024)); % proportional font size
Screen('TextFont', w, 'Times'); % seems needed for Windows
str = 'This will test your RT to gabor orientation identification.';
DrawFormattedText(w, str, 'center', r(4)*0.3, [255 0 0]);
str  =sprintf('We will do %d trials. When you see a tilted gabor:', nTrials);
DrawFormattedText(w, str, 'center', r(4)*0.35, [255 0 0]);
str = sprintf('press one of the left buttons if it tilts to left,');
DrawFormattedText(w, str, 'center', r(4)*0.4, [255 0 0]);
str = sprintf('press one of the right button if it tilts to right');
DrawFormattedText(w, str, 'center', r(4)*0.45, [255 0 0]);
DrawFormattedText(w, 'Scanner TR or key 5 will start trials', 'center', r(4)*0.6, 255);
Screen('Flip', w); % show instruction

txtsz = Screen('Textbounds', w, 'M');
ycenter = round(r(4)/2-txtsz(4)/2); % vertical center for feedback

% generate texture tilted to left, will rotate 2*dAngle to tilt right
imgsz = round(radius*ppd*2); % image size in pixels
rect = CenterRect([0 0 imgsz imgsz], r); % stim rect
[x, y] = meshgrid(linspace(-radius,radius,imgsz)); % symmetric coordinates
mask = exp(-(x.^2 + y.^2)/(radius/2)^2);  % gaussian mask: 0 to 1
angl = -dAngle/180*pi; % radian of -dAngle
img = sin(2*pi*sf*(x*cos(angl)+y*sin(angl))); % grating tilted left from vertical
img = img .* mask; % apply mask
tex = nan(1, ncond);
for i = 1:ncond
    img0 = img * contrast(i); % apply contrast
    img0 = round((img0+1)*127); % convert from [-1 1] to [0 254]
    tex(i) = Screen('MakeTexture', w, img0); % texture
    Screen('FrameOval', tex(i), 140, [0 0 imgsz imgsz]); % circle
end
clear x y mask img img0; % later, we need texture only

Priority(MaxPriority(w));   % raise priority for better timing
t0=RTBox('WaitTR'); % wait for scanner TR or key press 5
tStr = datestr(now); % for record
Screen('FrameOval', w, 140, rect); % circle
vbl=Screen('Flip', w);  %#ok turn off instruction

startSecs = (0:nTrials)*trialDur + t0+lagg; % start secs of each trial
startSecs = startSecs + rand(1,nTrials+1)*0.2; % small jitter for MRI+EEG
stimDur = (round(stimDur/ifi)-0.5)*ifi; % half refresh interval shorter
WaitTill(startSecs(1)-0.5); % wait till time of first trial

for i = 1:nTrials
    cond = record(i,2);
    angl = dAngle*record(i,3)*2; % 0 or dAngle*2 in deg
    Screen('DrawTexture', w, tex(cond), [], rect, angl); % draw to buffer
    Screen('DrawingFinished', w);
    
    WaitTill(startSecs(i)-0.5);  % wait till trial start time
    RTBox('clear');   % clear right before stimulus onset
    vbl = Screen('Flip', w, startSecs(i));  % show stim, return onset time
    t_onset = RTBox('TTL', 1); % mark stim onset in EEG, should be very close to vbl
    Screen('FrameOval', w, 140, rect); % circle
    Screen('Flip', w, vbl+stimDur); % turn off stim and show circle
    Screen('FrameOval', w, 140, rect); % circle
    
    record(i,6) = vbl-t0;  % stim start secs
    record(i,7) = t_onset-vbl;  % trigger time delay from flip time
    
    [t, btn] = RTBox(startSecs(i+1)-0.5); % return computer time and button
    
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
        correct = record(i,3) == strcmp(btn,'right');
        record(i, 4:5) = [correct t];
        
        % feedback
        if correct, str = 'Correct'; else str = 'Wrong'; end
    end
    DrawFormattedText(w, str, 'center', ycenter, 0);
    Screen('Flip', w);
end

WaitTill(startSecs(nTrials)+lagg); % wait till lead out
Priority(0);      % restore normal priority

% save myresult record t0 lagg trialDur randSeed;  % save a MAT file
% display or save result
fid = 1; % display in command window
% fid=fopen('myresult.txt', 'w+'); % you should save result in a file
fprintf(fid, 'trialDur = %g\n', trialDur);
fprintf(fid, 'lagg = %g\n', lagg);
fprintf(fid, 'randSeed = %d\n', randSeed);
fprintf(fid, 't0 = %.4f\n5', t0); % start time. Useful with RTBoxWarningLog.txt
fprintf(fid, 'Started at %s\n\n', tStr);
fprintf(fid, ' %s\n', recLabel);
fprintf(fid, '%6g %4g %9g %11g %8.4f %9.4f %9.4f\n', record'); % one trial per row
fprintf(fid, '\nFinished at %s\n', datestr(now));
fclose('all'); % no complain for fid=1
