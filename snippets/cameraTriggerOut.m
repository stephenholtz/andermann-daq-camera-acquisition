% Simple script to make digital output for camera triggering off nidaq
% 
% This is needed becuase the Mightex Cameras will not send a strobe out
% but this seems to work fine, commented below are lines to send out 3.3
% from analog ouput channels.
%
% SLH 2014
close all force;
clear all force;
daqreset; clc;

%#ok<*NBRAK,*UNRCH>
dS = daq.createSession('ni');

% Determine devID with daq.GetDevices
devID = 'Dev1';

% Hacky method for doing this with digital IO (only @5V)
dIO = dS.addDigitalChannel(devID,'Port0/Line0','OutputOnly');

% Even more hacky way for triggering 3.3V
%dAO = dS.addAnalogOutputChannel(devID,'ao0','Voltage');

% USB-6008 doesn't have clocked sampling, so we use this loop instead...
frameRateHz = 15;
pauseTime   = 1/frameRateHz - .005;

% Keyboard interrupt out of the loop
dS.outputSingleScan(0);
pause(pauseTime);
while 1
    dS.outputSingleScan(0)
    % Pause for framerate determined time minus a bit of lag 
    pause(pauseTime);
    
    dS.outputSingleScan(1)
    %dS.outputSingleScan(5)
end
