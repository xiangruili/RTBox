% This is a demo showing how to measure reaction time using RTBox.
% Run the program and follow the instruction in the command window.
% The program will measure and plot your RT.
% The result RT is a little longer since the start time is recorded 
% before sound play. The gaussian envolop also causes a small delay.

% 03/2008   wrote it
% 01/2012   use PsychPortAudio to replace legacy Snd
   
function RTBoxdemo_audio
nTrials = 10; % number of trials
timeout = 2; % timeout in second for RT reading

% make a brief beep with gaussian envolope
x = (-80 : 0.2 : 80); 
x = sin(x) .* exp(-(x / 55) .^ 4);
beep = [x; x]; % define sound wave
InitializePsychSound;
pahandle = PsychPortAudio('Open', [], 1, 1, 44100, 2); 
PsychPortAudio('FillBuffer', pahandle, beep);
PsychPortAudio('Start', pahandle);

rt = nan(nTrials, 1);
RTBox('clear');  % initialize device

Priority(1);   % raise priority for better timing

% print some instruction in Command Window
more off; % neede for Octave to show following instruction
fprintf('This will test your response time to %g beeps.\n', nTrials);
fprintf('When you hear a beep, press a button as soon as possible.\n');
fprintf('Press any button to start.\n');
RTBox(inf);  % wait till any enabled event
fprintf('Trial No:   ');

for i = 1:nTrials
    fstr = repmat('\b', 1, numel(num2str(i-1))+1); 
    fprintf([fstr '%g\n'], i); % replace old No with new one
    PsychPortAudio('Stop', pahandle); % this makes 'start' faster
    WaitSecs(1+rand*2); % random interval
    RTBox('clear'); % clear fake response and synchronize clocks
    
    t0 = PsychPortAudio('Start', pahandle, 1, 0, 1); % play sound, return onset time
    t = RTBox(timeout); % read time
    if isempty(t), continue; end  % no response, skip it
    t = t - t0; % RT
    if numel(t)>1
        % in case more than 1 press, print some information
        fprintf(' trial %2g: RT=', i); fprintf('%8.4f', t); fprintf('\n');
        ind = find(t>0.02,1); % find first proper rt
        if isempty(ind), continue; end  % no reasonable response, skip it
        t = t(ind); % use reasonable one
    end
    rt(i) = t;
end
Priority(0);  % restore normal priority
PsychPortAudio('Close');

% plot result
h = figure(9); set(h, 'color', [1 1 1]); 
plot(rt, '+-');
set(gca, 'box', 'off', 'tickdir', 'out');
ylabel('Reaction Time (s)'); xlabel('Trials');
rt(isnan(rt)) = []; % remove NaNs due to missed trials
str=sprintf('Your median RT: %.3f +- %.3f s', median(rt), std(rt));
title(str);
