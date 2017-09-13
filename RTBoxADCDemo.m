% This is a demo showing how to use the RTBox as an analog-to-digital
% converter to check the timing and relative brightness of light. The two
% optional input are background color and the new color you like to change
% to, both from 0 to 255. 
% 
% You need to connect the light sensor to the light port, and attach it to
% the center of the screen where the light signal will show. 
% 
% For hardware of v5.x, the light signal is connected to channel 8, so you
% don't need any other connection.  
% 
% For hardware of v4.x, you need to connect the light signal from the light
% sensor. Loosen the light sensor connector, and use a wire (better with an
% alligator at one end) to connect the central pin to pin 8 at the DB25
% port. 
% 
% For hardware of v1.x, the light signal is connected to channel 8 in the
% box, so there is no extra connection needed. But due to the capacitor
% (C01), the timing is slowed down. It is suggested to remove C01 (it won't
% affect anything).

function RTBoxADCDemo(back, newVal)
if nargin<2 || isempty(newVal), newVal=255; end % target color
if nargin<1 || isempty(back), back=0; end % background color

[w, res]=Screen('OpenWindow', max(Screen('screens')), back);
HideCursor;
hz = FrameRate(w);
rect = CenterRect([0 0 100 20], res); % target location
Screen('Flip', w);

% here we show different number of frames for each iteration
nFrames = [1 2 3 6];
dur = max(nFrames)/hz + 0.05; % use the longest duration
RTBoxADC('duration', dur);
% RTBoxADC('VRef', 2.56); % optionnal for v5 hardware

WaitSecs(0.2); % allow screen background to stablize
for i = nFrames
    Screen('FillRect', w, newVal, rect);
    t0 = Screen('Flip', w); % turn on the light bar

    RTBoxADC('start');  % start AD conversion, and return to matlab
    t1 = Screen('Flip', w, t0+(i-0.5)/hz); % turn off light after i frames 
    WaitSecs(dur-(t1-t0)+0.01); % wait till ADC done 

    RTBoxADC('read'); % read and show the result
    if i==nFrames(1), hold all; end % append later plots to figure
end
legend(cellstr(num2str(nFrames(:))));
title(sprintf('Light Signal (%g -> %g)', back, newVal));
hold off;
sca;
