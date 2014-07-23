% Ball output/counter logging test
% 
% Uses quadrature encoding, can be read w/ NI PICe-6321 A,Z,B counters: 
% CTR 2 A = PFI 0, CTR 2 B = PFI 2, CTR 2 Z = PFI 1
% all are ID'd under Terminal{A,B,Z} property of counter object, and CTR2
% is the only one accessible via just spring terminal block connections
% 
% Lines on the quadrature rotary encoder (YUMO CWZ3E 1024 P/R):
% A = Black; White = B; Orange = Z;
% 
% SLH 2014
close all force;
clear all force;
daqreset; clc;

%#ok<*NBRAK,*UNRCH>
dS = daq.createSession('ni');

%=BALL ACQUISITION=========================================================
ctr2 = dS.addCounterInputChannel('Dev1',[2],'Position');

% Set quadrature encoding properties
ctr2.Name           = 'ball_quadrature';
ctr2.EncoderType    = 'X4';
ctr2.ZResetEnable   = 1;
ctr2.ZResetValue    = 0;
ctr2.ZResetCondition= 'BothHigh';

% Set continuous 1kHz acquisition properties
dS.Rate         = 1000;
dS.IsContinuous = true;

% create file to write data to (dir must exist)
logFileName = fullfile('C:','temp_daq_data',['logfile_' datestr(now,30) '.bin']);
fid1 = fopen(logFileName,'w+');

% add listener for DataAvailable
debugBallData = 0; 
if debugBallData
    % plot the output for debugging
    lH  = dS.addlistener('DataAvailable',@(src,event)plot(event.TimeStamps,event.Data));
else
    % save the output to a log file
    lH = dS.addlistener('DataAvailable',@(src,event)logData(src,event,fid1));
end

% NOTE: this requires adding an analog input / output channel on the device
[~] = dS.addAnalogInputChannel('Dev1','ai0','Voltage');

%=STROBE / ANALOG ACQUISITION==============================================




% Start acquisition in the background
dS.startBackground;

nSeconds = 10;
pause(nSeconds);

dS.stop;
delete(lH);
fclose('all');

fid1 = fopen(logFileName,'r+');
loggedData=fread(fid1,[2 inf]);
plot(loggedData(1,:)');
