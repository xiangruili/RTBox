% This is a demo showing how to measure reaction time using RTBox. The task is
% to identify the orientation of garbor. If garbor tilts to 11 o'clock, press
% left button; if to 1 o'clock, press right button. The result will be displayed
% in command window.

% Xiangrui Li, 8/2008
   
function RTBoxdemo_Orientation(scrn)
if nargin<1, scrn = max(Screen('screens')); end % find last screen
nTrials = 10; % # of trials
timeout = 3; % timeout for RT reading
radius = 3; % garbor radius in visual degrees
dAngle = 5; % tilt degree from vertical
sf = 1; % spatial freq: cycles per deg
contrast = 0.3; % garbor contrast
ppd = 42; % display property: pixels per degree

% record contains stim info and response. 
% We assign NaN to missed and unreasonable response.
record = nan(nTrials, 5); % 5 columns: iTrial tiltRight respCorrect RT startSecs
record(:,1) = 1:nTrials; % # of trial
LR = ones(nTrials,1); LR(1:round(nTrials/2)) = 0; % half ones, half zeros
record(:,2) = Shuffle(LR); % 1 for tilt right, 0 left

% Set button names. Also open RTBox if hasn't.
% We make two left buttons equivalent, and the right buttons equivalent
oldButtons = RTBox('ButtonNames', {'left' 'left' 'right' 'right'});

[w, res] = Screen('OpenWindow', scrn, 127);  % open a gray screen
clnObj = onCleanup(@() sca);
HideCursor;
ifi = Screen('GetFlipInterval', w); % flip interval

% print some instruction
Screen('TextSize', w, round(24/res(4)*1024)); % proportional font size
Screen('TextFont', w, 'Times'); % seems needed for Windows
str = ['This will test your RT to garbor orientation identification.\n\n' ...
    'We will do ' num2str(nTrials) ' trials. When you see a tilted garbor:\n\n' ...
    'press any of left buttons if it tilts to left,\n\n' ...
    'press any of right buttons if it tilts to right'];
[~, ny] = DrawFormattedText(w, str, 'center', 'center', [255 0 0]);
DrawFormattedText(w, 'Press any button to start', 'center', ny+50, 255);
Screen('Flip', w); % show instruction

% generate a texture tilted to left, will rotate 2*dAngle to tilt right
imgsz = round(radius*ppd*2); % image size in pixels
rect = CenterRect([0 0 imgsz imgsz], res); % stim rect
[x, y] = meshgrid(linspace(-radius, radius, imgsz)); % symmetric coordinates
mask = exp(-(x.^2 + y.^2)/(radius/2)^2); % gaussian mask: 0 to 1
img = sin(2*pi*sf*(x*cosd(-dAngle) + y*sind(-dAngle))); % grating tilted left from vertical
img = img * contrast .* mask; % apply contrast and mask
img = uint8((img+1)*127); % convert from [-1 1] to [0 254]
tex = Screen('MakeTexture', w, img); % texture
clear x y mask img; % later, we need texture only

Priority(MaxPriority(w));   % raise priority for better timing
RTBox('clear'); % remove any previous events
t0 = RTBox(1000);  % wait 1000 s, or till any enabled event
tStr = datestr(now); % for record
Screen('FrameOval', w, 140, rect); % circle
vbl = Screen('Flip', w); %#ok turn off instruction, show circle

for i = 1:nTrials
    angl = dAngle*record(i,2)*2; % 0 or dAngle*2 in deg
    Screen('DrawTexture', w, tex, [], rect, angl); % draw to buffer
    Screen('FrameOval', w, 140, rect); % circle
    
    WaitSecs(1+rand*2); % random interval for subject
    RTBox('clear'); % clear right before stimulus onset
    vbl = Screen('Flip', w); % show stim, return onset time
    record(i,5) = vbl-t0; % startSecs
    Screen('FrameOval', w, 140, rect); % circle
    Screen('Flip', w, vbl+ifi*1.5); % turn off stim and show circle
    
    [t, btn] = RTBox(timeout); % return computer time and button
    
    % check response
    if isempty(t), continue; end % no response, skip the trial
    t = t- vbl - ifi/2; % RT now, roughly calibrate offset
    if numel(t)>1 % more than 1 response
        fprintf(' #trial %2g: RT = ',i); fprintf('%8.4f',t); fprintf('\n');
        ind = find(t>0.1, 1); % find the 1st proper rt
        % you may set your criterion, for example t>0.2
        if isempty(ind), continue; end  % no reasonable response, skip trial
        t = t(ind); btn = btn{ind}; % use the first reasonable response
    end
    
    % record correctness and RT
    record(i, 3:4) = [record(i,2)==strcmp(btn,'right') t];
end

Priority(0);      % restore normal priority
RTBox('ButtonNames', oldButtons); % restore button names

% save myresult record t0;  % save result into MAT file

% display or save result
fid = 1; % display in command window
% fid=fopen('myresult.txt','w+'); % you should save result in a file
fprintf(fid, 't0 = %.4f\n',t0); % start time. Useful with RTBoxWarningLog.txt
fprintf(fid, 'Started at %s\n\n', tStr);
fprintf(fid, ' trial tiltRight respCorrect respTime startSecs\n');
fprintf(fid, '%6g %9g %11g %8.4f %.4f\n', record'); % one trial per row
fprintf(fid, '\nFinished at %s\n', datestr(now));
fclose('all'); % no complain for fid=1


