% [...] = RTBoxes(cmd, parameter, boxNames);
% 
% This is a shortcut to use multiple response boxes. It uses the same
% syntax as RTBox, except that you normally provide a cellstr, boxNames, as
% last argument for all the device names, e.g., {'device1' 'device2'
% 'device3'}. If no device name is provided, it will be the same as calling
% RTBox without device name.
% 
% Basically, this performs the command for each box one by one for most
% subfunctions, except read functions. For read functions, the timeout
% parameter applies to all devices. For example, 
% [t b]=RTBoxes(timeout,{'device1' 'device2'}) 
% will return after timeout reaches. If you do this to each device, the
% reutrned time will be twice of timeout.
%
% Limitation: in the rare case you want to return time relative to a button
% event, you must use same button names for all devices.
% 
% See Also: RTBox

% Xiangrui Li (xiangrui.li@usc.edu), 3/2009

function  varargout = RTBoxes (varargin)
nIn=nargin; % check whether device is specified
if nIn<1 || ~iscellstr(varargin{nIn}) || ~strncmpi('device',varargin{nIn}{1},6)
    boxID={'device1'}; % no device specified
else
    boxID=varargin{nIn}; nIn=nIn-1; % don't count last argin
end

% deal with variable number of input
switch nIn
    case 0, in1=[]; in2=[];
    case 1 % could be cmd or timeout
        if ischar(varargin{1}), in1=varargin{1}; in2=[];
        else in1=[]; in2=varargin{1};
        end
    case 2, [in1, in2]=varargin{1:2};
    otherwise, error('Too many input arguments.');
end
if isempty(in1), in1='secs'; end % default command
cmd=lower(in1);  % make command and trigger case insensitive

nDevice=numel(boxID);
out=repmat({[] ''},nDevice,1);

info=RTBox('info', boxID{1});
read=[info.events(1:8) {'light' 'pulse' '5' 'serial' 'secs' 'boxsecs'}];
nOut=nargout;

if ~any(strcmp(cmd,read)) %  not read subfuction
    inCell{1}=cmd;
    if nIn>1, inCell{2}=in2; end
    inCell{end+1}=boxID{1};
    for i=1:nDevice
        inCell{end}=boxID{i};
        [out{i,1:nOut}]=RTBox(inCell{:});
    end
else
    responded=false(1,nDevice);
    if isempty(in2), in2=0.1; end
    useUntil=RTBox('UntilTimeout'); % check for first device
    if useUntil, tStop=in2; else tStop=GetSecs+in2; end
    while GetSecs<tStop && sum(responded)<nDevice
        for i=1:nDevice
            if responded(i), continue; end
            [out{i,1:nOut}]=RTBox(in1,0.01,boxID{i});
            responded(i)=~isempty(out{i,1});
        end
    end
end
for i=1:nOut
    varargout{i}=out(:,i); %#ok
end
