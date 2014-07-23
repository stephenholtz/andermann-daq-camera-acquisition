% Scratchwork for testing
%
% NI PCIe-6321 on Dev1

%%
daqreset;
close all force;
clear all force; 

dS = daq.createSession('ni');

devID = 'Dev1';
dIO = dS.addDigitalChannel(devID,{'Port0/Line0:7'},'InputOnly');
aI = dS.addAnalogInputChannel(devID,[0 1 2 3],'Voltage');

dS.DurationInSeconds = 4;
dS.Rate = 1000;

[dataIn, countIn] = dS.startForeground();

%%
plot(countIn,dataIn);