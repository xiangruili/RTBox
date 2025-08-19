function varargout = RTBoxADC (cmd, varargin)
% RTBoxADC (cmd, para)
%
% RTBoxADC uses RTBox as analog to digital converter.
%
% RTBoxADC;
% - Without any input arguemnet, it will display the trace continuously like an
% oscilloscope. It provides an interface to change parameters. For better
% controlled acquisition, use other sub-commands as shown in RTBoxADCDemo.m.
%
% RTBoxADC('channel', 8);
% RTBoxADC('channel', 'dif', gain);
% - Set ADC input channel. For hardware v4.x, it can be 5~8, corresponding to
% the DB-25 pins 5~8, default 8. For hardware v5 and later, it can be 1~8, where
% 1~7 correspond to the DA-15 pins 1~7, and 8 is reserved to light sensor.
%
% The input 'dif' means differential signal. The input pins are DA15 port 2
% (positive) and 1 (negative) for v5.x. For v3.x and v4.x, these pins are not
% connected to DB25 port. The 3rd input is the gain, which can be 1, 10 or 200.
%
% realRate = RTBoxADC('rate', 3600); - Set sampling rate. Currently, only
% several rates are acceptable: 3600, 900, 450, 225, 112.5 and 28.125 Hz. If
% other rate is requested, the closest rate will be used. The real rate will be
% returned if output is provided.
%
% RTBoxADC('duration', 0.1);
% - Set duration in seconds for acquisition.
%
% RTBoxADC('VRef', 5);
% - Set reference voltage for v5+. Available VRef values are 2.56, 3.3 or 5
% volts. v1 hardware has only 3.3V option.
%
% RTBoxADC('OneShot');
% - Start one-shot acquisition and display data.
%
% RTBoxADC('start');
% - Start the conversion and return to Matlab immediately. The data will be in
% serial buffer.
%
% [y, t] = RTBoxADC('read');
% - After RTBoxADC('start'), read and return the data, and optionally, the time
% based on real sampling rate. If no output is provided, it will show result in
% a figure.
%
% RTBoxADC('Close');
% - Close the port.

% History (yymmdd):
% 111001 wrote it (xl)
% 120101 ready for users (xl)
% 120601 v4.5 send 5 bytes (was 8) for each 4 samples
% 130301 update channel for v5, other costmetic changes
% 141125 Make it work for Octave (except 'continuous')
% 141219 bug fix for RTBoxADC ID test
% 160912 take care of ver for v>1.9 && v<2
% 170614 bug fix for more than one RTBox case
% 171118 Make it work for serFTDI

persistent s port rates ver osc byteRatio tObj bytes;
persistent rate dur ch gain isdif vref ADMUX;
if nargin<1, cmd = 'continuous'; end
if any(cmd=='?'), subFuncHelp('RTBoxADC', cmd); return; end
if isempty(s)
    if strcmpi(cmd, 'close'), return; end
    dur = 0.1; % default duration
    rates = 7372800 / 256 ./ [8 32 64 128 256 1024];
    [port, ver] = RTBoxPorts(1); % get all ports for RTboxes
    if isempty(port), error(' No working RTBox found.'); end
    validVer = (ver>=1.8 & ver<3) | ver>=4.2;
    port = port(validVer); ver = ver(validVer);
    if isempty(ver)
        error(' No working RTBox with ADC found.');
    elseif numel(ver)>1 % more than one boxes connected
        fprintf(' More than one RTBoxes found. Using the one at %s (v%g)', ...
            port{1}, ver(1));
    end
    port = port{1}; ver = ver(1);
    s = serIO('Open', port);
    serIO('Write', s, 'G'); % jump into ADC function
    b = serIO('Read', s, 8);
    if ~strcmp(char(b), 'RTBoxADC')
        serIO('Close', s); s = [];
        error(' It seems RTBoxADC firmware is not uploaded.');
    end
    if ver<2, vref = 3.3; else, vref = 5; end
    if ver<5, ADMUX = 7; else, ADMUX = 64; end % REFS1 REFS0 =[0 1] for v5
    RTBoxADC('channel', 8); % default channel
    RTBoxADC('rate', 3600); % default sampling rate
    
    if ver>=4.5 || (ver>1.9 && ver<2)
        byteRatio = 1.25;
    else
        byteRatio = 2;
    end
    tObj = timer('ExecutionMode', 'fixedRate', 'Name', 'RTBoxADC_timer');
    osc.clean = onCleanup(@() closeRTBoxADC(s, port, osc));
end

switch lower(cmd)
    case 'start'
        if strcmp(tObj.Running, 'on'), stop(tObj); end
        bytes = [];
        serIO('Read', s); % purge
        serIO('Write', s, uint8(2)); % start conversion
        set(tObj, 'TimerFcn', 'RTBoxADC(''timerRead'')', 'Period', 0.05);
        start(tObj);
    case 'timerread'
        bytes = [bytes serIO('Read', s)];
    case 'read'
        stop(tObj);
        n = round(dur*rate/4)*4 * byteRatio;
        if numel(bytes)<n
            WaitSecs(0.05);
            bytes = [bytes serIO('Read', s, n-numel(bytes))];
        end
        
        n = numel(bytes);
        dp = 5; if byteRatio==2, dp = 2; end
        n = floor(n/dp) * dp;
        v = byte2vol(bytes(1:n), byteRatio, isdif, gain, vref);
        
        t = (0:n/byteRatio-1)'/rate;
        if nargout, varargout = {v t};
        else
            plot(t, v);
            xlabel('Time (s)'); ylabel('Voltage (V)');
        end
    case 'channel'
        if nargin<2, varargout{1} = ch; return; end
        ch = varargin{1};
        if ischar(ch) % differential
            % ADMUX   Channels  Gain
            % 0b01000 ADC0-ADC1 1
            % 0b01001 ADC1-ADC0 10
            % 0b01011 ADC1-ADC0 200
            isdif = 1;
            if nargin<3
                gain = -1; ch1 = 16; % make gain=-1, so it is ADC1-ADC0
            else
                gain = varargin{2};
                if ~any(gain == [1 10 200])
                    error(' gain must be 1, 10 or 200.');
                end
                if gain==1, gain = -1; ch1 = 16;
                elseif gain==10, ch1 = 9;
                else, ch1 = 11;
                end
            end
        else
            gain = 1;
            isdif = 0;
            ch1 = ch-1;
        end
        ADMUX = floor(ADMUX/64)*64 + ch1;
        serIO('Write', s, uint8([67 ADMUX]));
        if nargout, varargout{1} = ch; end
    case 'rate'
        if nargin<2, varargout{1} = rate; return; end
        rate = varargin{1};
        [~, iRate] = min(abs(rate-rates));
        if rate ~= rates(iRate)
            rate = rates(iRate);
            warning('RTBoxADC:rate',' Real rate will be %g Hz.', rate);
        end
        serIO('Write', s, uint8([70 iRate+1])); % set rate
        RTBoxADC('duration', dur)
        if nargout, varargout{1} = rate; end
    case 'duration'
        if nargin<2 || nargout, varargout{1} = dur; end
        if nargin<2, return; end
        dur = varargin{1};
        n = round(dur*rate/4)*4;
        if n>65535, error('Max points to acquire is 2^16-1'); end
        dur = n/rate;
        serIO('Write', s, uint8([110 floor(n/256) mod(n,256)]));
    case 'vref'
        if nargin<2 || nargout, varargout{1} = vref; end
        if nargin<2, return; end
        in2 = varargin{1};
        if (ver<2 && in2~=3.3) || (ver<5 && in2~=5) || ...
                (ver>=5 && ~any(in2 == [2.56 5]))
            warning('RTBoxADC:VRef',' Invalid VRef for your hardware.');
            return;
        end
        vref = in2;
        if ver>=5
            if vref == 5, refSel = 64;
            else, refSel = 192;
            end
            ADMUX = mod(ADMUX,64) + refSel;
            serIO('Write', s, uint8([67 ADMUX]));
        end
    case 'oneshot'
        RTBoxADC('start');
        WaitSecs('YieldSecs', dur+0.1);
        RTBoxADC('read');
    case 'continuous'
        if nargin>1, in2 = varargin{1}; else, in2 = 'setup'; end
        switch in2
            case 'update' % called by timer
                bp = 5; if byteRatio==2; bp = 2; end
                n = serIO('BytesAvailable', s);
                n = floor(n/bp) * bp;
                if n==0, serIO('Write', s, uint8(2)); return; end
                b = serIO('Read', s, n);
                v = byte2vol(b, byteRatio, isdif, gain, vref);
                ind = (0:n/byteRatio)+osc.i;
                ind = mod(ind-1, osc.nP)+1;
                osc.y(ind) = [v; nan];
                osc.i = ind(end);
                set(osc.plot, 'YData', osc.y);
            case 'xmax' % called when changing X Range
                val = round(10*get(osc.slider,'Value'))/10;
                osc.nP = round(rate*val);
                osc.x = (0:osc.nP-1)'/rate;
                n = numel(osc.y);
                if n>osc.nP, osc.y(1:(n-osc.nP)) = [];
                elseif n<osc.nP, osc.y = [osc.y; nan(osc.nP-n,1)];
                end
                set(osc.plot, 'XData', osc.x, 'YData', osc.y);
                set(get(osc.plot, 'Parent'), 'xlim', osc.x([1 end]));
            case 'channel' % called when changing channel
                n = get(osc.ch, 'Value');
                if n<=8, RTBoxADC('channel', n);
                elseif n==9,  RTBoxADC('channel', 'dif', 1);
                elseif n==10, RTBoxADC('channel', 'dif', 10);
                elseif n==11, RTBoxADC('channel', 'dif', 200);
                end
            case 'rate' % called when changing rate
                RTBoxADC('rate', rates(get(osc.rate, 'Value')));
                RTBoxADC('continuous', 'xmax');
                intvl = max(0.015, round(4000/rate)/1000);
                if ~isvalid(tObj), return; end
                intv0 = get(tObj, 'Period');
                if intvl~=intv0
                    stop(tObj);
                    set(tObj, 'Period', intvl);
                    serIO('Read', s);
                    start(tObj);
                end
            case 'close' % called when closing the figure
                if isvalid(tObj)
                    stop(tObj);
                    osc = rmfield(osc, 'slider');
                end
                osc.clean = []; % evoke closeRTBoxADC 
            case 'stop' % called when Stop/Start button is pressed
                if ~isfield(osc, 'go'), osc.go = gco; end
                if strcmp(get(osc.go, 'String'), 'Stop')
                    set(osc.go, 'String', 'Start', 'BackgroundColor', 'g');
                    if isvalid(tObj), stop(tObj); end
                else
                    set(osc.go, 'String','Stop', 'BackgroundColor', 'r');
                    RTBoxADC('continuous', 'setup'); % start timer
                end
            case 'setup' % called first time to start the display
                if ~isfield(osc, 'i')
                    osc.i = 1;
                    osc.nP = round(rate*3);
                    osc.x = (0:osc.nP-1)'/rate;
                    osc.y = nan(osc.nP,1);
                end
                hFig = figure(3);
                
                if ~isfield(osc, 'slider') || isempty(get(osc.slider, 'Value'))
                    set(hFig, 'DeleteFcn', 'RTBoxADC(''continuous'',''close'');', ...
                        'Toolbar', 'figure');
                    osc.go = uicontrol('Style', 'pushbutton', 'String', 'Stop',...
                        'units', 'normalized ', 'Position', [0.83 0.93 0.08 0.06], ...
                        'BackgroundColor', 'r', ...
                        'Callback', 'RTBoxADC(''continuous'',''stop'');');
                    osc.slider = uicontrol('Style', 'slider', 'Min',0.1, 'Max',10, ...
                        'Value', 3, 'SliderStep', [0.01 0.1], ...
                        'units', 'normalized ', 'Position', [0.685 0.93 0.14 0.05], ...
                        'Callback', 'RTBoxADC(''continuous'',''xmax'');');
                    uicontrol('Style', 'text', 'String', 'X Range:', ...
                        'units', 'normalized ', 'Position', [0.58 0.93 0.1 0.045]);
                    if ischar(ch), nCh = find(gain==[1 10 200])+8;
                    else, nCh = ch;
                    end
                    if ver<5, chStr = '1|2|3|4|5|6|7|8|2-1 x1|2-1 x10|2-1 x200';
                    else, chStr = '1|2|3|4|5|6|7|8|1-2 x1|1-2 x10|1-2 x200';
                    end
                    osc.ch = uicontrol('Style', 'popupmenu', 'Value', nCh,...
                        'String', chStr, ...
                        'units', 'normalized ', 'Position', [0.3 0.92 0.12 0.06], ...
                        'Callback', 'RTBoxADC(''continuous'',''channel'');');
                    uicontrol('Style', 'text', 'String', 'Channel:', ...
                        'units','normalized ','Position', [0.21 0.93 0.09 0.045]);
                    osc.rate = uicontrol('Style', 'popupmenu', 'Value', find(rate==rates),...
                        'String', cellstr(num2str((rates)', '%.4g')), ...
                        'units', 'normalized ', 'Position', [0.46 0.92 0.09 0.06], ...
                        'Callback', 'RTBoxADC(''continuous'',''rate'');');
                    uicontrol('Style', 'text', 'String', 'Hz', ...
                        'units', 'normalized ', 'Position', [0.55 0.93 0.03 0.045]);
                    osc.plot = plot(osc.x, osc.y);
                    set(gca, 'xgrid', 'on', 'ygrid', 'on', 'xlim', osc.x([1 end]));
                    % set(gca, 'ylim', [0 vref]);
                    xlabel('Time (s)'); ylabel('Voltage (V)');
                end
                
                stop(tObj);
                intvl = max(0.015, round(4000/rate)/1000);
                set(tObj, 'TimerFcn', 'RTBoxADC(''continuous'',''update'');', 'Period', intvl);
                serIO('Read', s);
                serIO('Write', s, uint8(2));
                start(tObj);
        end
    case 'close'
        closeRTBoxADC(s, port, osc)
        clear s rate dur;
    otherwise
        error(' Unknown command.');
end

% convert data from bytes to voltage
function vol = byte2vol(byte, byteRatio, isdif, gain, vref)
if byteRatio<2 % 1.25
    byte = reshape(byte(:), 5, []);
    vol = bitand(byte(5,:), [3 12 48 192]') .* [256 64 16 4]';
    vol = vol + byte(1:4, :);
    vol = vol(:);
else
    vol = reshape(byte(:), 2, []);
    vol = [1 256] * vol;
    vol = vol(:);
end
if isdif
    vol(vol>511) = vol(vol>511)-1024;
    vol = vol/gain*2;
end
vol = vol/1024*vref;

function closeRTBoxADC(s, port, osc)
tObj = timerfind('Name', 'RTBoxADC_timer');
if isvalid(tObj), stop(tObj); end
try %#ok
    set([osc.ch osc.slider osc.rate], 'Enable', 'off');
    set(osc.go, 'String','start', 'BackgroundColor', 'g');
end
[s0, ~] = serIO('Open', port);
if s0>=0, s = s0; end
% could return to RTBox firmware here
serIO('Close', s); % close port
