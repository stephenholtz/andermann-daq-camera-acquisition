% acquireNidaqToDisk.m
%
% Script acquires digital and analog channels from behavioral and
% retinotopic experiments. Acquires continuously to disk in a logfile.
% Then saves the logfile as a .mat file for lab compatibility.
% Additionally sends out 5V triggers for acquisition from connected
% cameras.
%
% NOTE: Mightex camera works with 5V in spite of documentation!
% 
% SLH
%#ok<*NBRAK,*UNRCH>

%% Initialization

% Close DAQ connections and reset acquisition devices
close all force; 
clear all force;
daqreset;

%--------------------------------------------------------------------------
% Edit for each animal/experiment change
%--------------------------------------------------------------------------
animalName      = 'K69';
expName         = 'ML-v1';

% Send triggers for qimaging acquisition @ some rate (Hz)
triggerQimagingCCD  = 0;
qImagingCCDRateHz   = 30; 
% Send triggers for Mightex / ptGrey acquisition @ some rate (Hz)
triggerMightexCam   = 0;
mightexCameraRateHz = 15;
triggerPtGreyCam    = 0;
ptGreyCameraRateHz  = 40;

%--------------------------------------------------------------------------
%-Set up filepaths for logging---------------------------------------------
%--------------------------------------------------------------------------
tmpDaqFolderName    = 'C:\temp_daq_data';
fullDateTime        = datestr(now,30);
expDate             = fullDateTime(1:8);
daqSaveDir = fullfile(tmpDaqFolderName,animalName,expDate);
daqSaveFile = [fullDateTime '_' expName '_' animalName '.dat'];
matSaveFile = [fullDateTime '_' expName '_' animalName '.mat'];
if ~exist(daqSaveDir,'dir')
    mkdir(daqSaveDir);
end

%--------------------------------------------------------------------------
%-Base daq devices and channels--------------------------------------------
%--------------------------------------------------------------------------
niIn = daq.createSession('ni');
% Determine devID with daq.GetDevices or NI's MAX software
devID = 'Dev1';

% Continuously acquire to log file at 10kHz
niIn.Rate         = 10E3;
niIn.IsContinuous = true;

logFileID = fopen(fullfile(daqSaveDir,daqSaveFile),'w');
niIn.addlistener('DataAvailable',@(src,evt)logDaqData(src,evt,logFileID));

% Add Analog Channels / names for documentation
aI = niIn.addAnalogInputChannel(devID,[0 1 2 3 4],'Voltage');
aI(1).Name = 'LED Stim Output';
aI(2).Name = 'Psych Toolbox Output';
aI(3).Name = 'Lick Port Output';
aI(4).Name = 'Reward (To Solenoid 1)';
aI(5).Name = 'Punishment (To Solenoid 2)';

% Add Digital Channels / names for documentation
dIO = niIn.addDigitalChannel(devID,{'Port0/Line0:7'},'Bidirectional');
dIO(1).Name = 'Q-Imaging Wide-field CCD SyncB'; 
dIO(2).Name = 'PointGrey Whisker Tracking Strobe In';
dIO(3).Name = 'Mightex Eye Tracking Strobe In';
dIO(4).Name = 'Monkeylogic Word (Behavioral Code) Strobe In';
dIO(5).Name = 'Monkeylogic Bit 1';
dIO(6).Name = 'Monkeylogic Bit 2';
dIO(7).Name = 'Monkeylogic Bit 3';
dIO(8).Name = 'Monkeylogic Bit 4';

% By default set all to Input
set(dIO(:),'Direction','Input')

% Separate Device for triggers, in this case they are non-clocked 
% operations. This should generate a warning about clocked operations on 
% most X series. Port 1 == PFI 1 
niTrig  = daq.createSession('ni');
dTrig   = niTrig.addDigitalChannel(devID,{'Port1/Line0:3'},'OutputOnly');
dTrig(1).Name = 'Q-Imaging Wide-field CCD Trigger';
dTrig(2).Name = 'PointGrey Whisker Tracking Trigger';
dTrig(3).Name = 'Mightex Eye Tracking Trigger';
dTrig(4).Name = 'none'; % Save for laser

% Add Counter Channels / names for documentation
%   CTR 3 A - PFI 5
%   CTR 3 Z - PFI 6
%   CTR 3 B - PFI 7
cI = niIn.addCounterInputChannel(devID,[3],'Position');
cI(1).Name = 'Ball Quadrature';

%--------------------------------------------------------------------------
%-Optional daq devices: camera triggers + timing functions etc-------------
%--------------------------------------------------------------------------

% Use timer function for the CCD, needs to agree with the rates in software
if triggerQimagingCCD
    qImagingTriggerPort = 1;
    qImagingTriggerVerbose = 0;
    % Change the trigger line to output
    set(dIO(qImagingTriggerPort),'Direction','Output') 

    tFCCD = timer('ExecutionMode','fixedDelay','BusyMode','queue','Period',1/qImagingCCDRateHz);
    tFCCD.StartDelay = 1;
    tFCCD.TimerFcn = {@sendAcqTrigger,niTrig,qImagingTriggerPort,qImagingTriggerVerbose};
end

% Use timer functions to send +5V triggers to PTGrey camera @ some rate
if triggerPtGreyCam
    ptGreyTriggerPort = 2;
    ptGreyTriggerVerbose = 0;
    % Change the trigger line to output
    set(dIO(ptGreyTriggerPort),'Direction','Output')

    tFptGrey = timer('ExecutionMode','fixedDelay','BusyMode','queue','Period',1/ptGreyCameraRateHz);
    tFptGrey.StartDelay = 1;
    tFptGrey.TimerFcn = {@sendAcqTrigger,niTrig,ptGreyTriggerPort,ptGreyTriggerVerbose};
end

% Use timer functions to send +5V triggers to Mightex camera @ some rate
if triggerMightexCam
    mightexTriggerPort = 3;
    mightexTriggerVerbose = 0;
    % Change the trigger line to output
    set(dIO(mightexTriggerPort),'Direction','Output')

    tFCam = timer('ExecutionMode','fixedDelay','BusyMode','queue','Period',1/mightexCameraRateHz);
    tFCam.StartDelay = 1;
    tFCam.TimerFcn = {@sendAcqTrigger,niTrig,mightexTriggerPort,mightexTriggerVerbose};
end

%% Running 

%--------------------------------------------------------------------------
%-Begin / end acquisition using timer funcitons----------------------------
%--------------------------------------------------------------------------
% Use timer functions to start and stop acquisition (silly syntax!)
tFAcq = timer();
tFAcq.Period = 1;
tFAcq.StartFcn = {@startAcqWithInput,niIn};
tFAcq.TimerFcn = {@stopAcqWithInput,niIn};

% Acquisition will quit using timer function prompts
start(tFAcq)

% Start sending other triggers, all of which have start delays and will not 
% collide with an error.
if triggerQimagingCCD;  start(tFCCD);   end
if triggerPtGreyCam;    start(tFptGrey);end
if triggerMightexCam;   start(tFCam);   end

pause(1)
wait(tFAcq)
stop(timerfindall)
delete(timerfindall)

[~] = fclose(logFileID);

%% Save / Cleanup

% Display savepaths / filenames
fprintf('\tAcquisition complete.\n\n')
fprintf('daqSaveDir: %s\n', daqSaveDir);
fprintf('daqLogFile: ..%s%s\n\n', filesep, daqSaveFile);

% Load in data and save as mat file for lab compatability
fprintf('Loading logged data into workspace... ')

logFileID = fopen(fullfile(daqSaveDir,daqSaveFile),'r');

nDaqChans = numel(dIO) + numel(aI);
[exp.Data,exp.Count] = fread(logFileID,[nDaqChans,inf],'double');
[~] = fclose(logFileID);

exp.daqChID     = {niIn.Channels(:).ID};
exp.daqChName   = {niIn.Channels(:).Name};
save(fullfile(daqSaveDir,matSaveFile),'exp','-v7.3');
fprintf('saved as .mat file.\n')
fprintf('\tdaqMatFile: ..%s%s\n\n', filesep, matSaveFile);
