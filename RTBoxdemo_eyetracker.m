% This shows how to use RTBox to send event code to eye tracker in DNI at
% USC. The RTBox TTL output is connected to both EEG system and eyetracker
% unit. 
% The command to send an event code is:
%  [tsent upperbound] = RTBox('TTL',eventCode);
% where eventCode is 1 though 15, which will be sent to both systems.
% 
% Note that the scanner TR is connected to bit 8, so there will be a 256
% for each TR. Your analysis code should choose to use either 0~15 or 256.
% Keep in mind if an event code happens at the same time as TR, you will
% see a code 256+eventCode in your eyetracker data. If evts is the column
% vector containing all event code, a simple way to remove TR triggers is
% 
%  ind=evts>255; evts(ind)=evts(ind)-256; % remove TR triggers
% 
% To remove the repeated events for a single event, using following code:
%  ind=diff([0; evts])<=0; evts(ind)=0; % remove repeated events

% Xiangrui, 09/2009, wrote it, plan to use two RT Boxes
% Xiangrui, 04/2010, Decide to use one box only

function RTBoxdemo_eyetracker
% suppose you have 4 conditions, each repeated 3 times
nCond = 4;
repeat = 3;
conTypes = repmat(1:nCond, 1, repeat); 
conTypes = Shuffle(conTypes); % shuffle them
% your conTypes may be from mseq, repeatedhistory or something alike

nTrials = numel(conTypes);  % number of trials
trialDur = 1;
lagg = 1;

startt = (0:nTrials)*trialDur+t0+lagg; % trial start time

RTBox('clear'); 
fprintf(' t0 = %.4f\n', t0);
fprintf(' Trial EventCode SentTime(GetSecs-t0) UpperBound\n');
   
for i = 1:nTrials
    WaitTill(startt(i));
    % prepare your stimulus
    % show your stimulus at scheduled time, and followed by TTL
    [t_onset, ub] = RTBox('TTL', conTypes(i)); % send condition type to eye tracker
    
    fprintf(' %5i %9i %20.4f %10.4f\n', i, conTypes(i), t_onset-t0, ub);

    % check response and do other things
end
