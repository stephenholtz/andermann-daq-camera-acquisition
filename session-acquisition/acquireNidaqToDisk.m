% acquireNidaqToDisk.m
%
% Script acquires digital and analog channels from behavioral and
% retinotopic experiments. Acquires continuously to disk in a logfile.
% Then saves the logfile as a .mat file for lab compatibility.
% Additionally sends out 5V triggers for acquisition from connected
% cameras.
%
% NOTE: Mightex camera works with 5V trig in spite of documentation.
% However, the TTL pulsewidth is very small, so a counter might be 
% needed to mark new frame events.
% 
% SLH
%#ok<*NBRAK,*UNRCH>

%% Initialization

% Close DAQ connections and reset acquisition devices
daqreset;

forceClear = 1;
if forceClear
    close all force; 
    clear all force;
end

%--------------------------------------------------------------------------
% Edit for each animal/experiment change
%--------------------------------------------------------------------------
animalName      = 'RS2';
expName         = 'ML-progress-check';

% Send triggers for qimaging acquisition @ some rate (rate potentially
% determined by other software)
triggerQimagingCCD  = 0;
qImagingCCDRateHz   = 30; 
% Send triggers for Mightex (rate is defined by trigger rate)
triggerMightexCam   = 1;
mightexCameraRateHz = 15;
% Sent start trigger for Point Grey camera acquisition (rate potentially
% defined by other software)
triggerPtGreyCam    = 1;

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
niIn.Rate         = 5E3;
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
dIO(3).Name = 'Monkeylogic Word (Behavioral Code) Strobe In';
dIO(4).Name = 'Monkeylogic Bit 1';
dIO(5).Name = 'Monkeylogic Bit 2';
dIO(6).Name = 'Monkeylogic Bit 3';
dIO(7).Name = 'Monkeylogic Bit 4';
dIO(8).Name = 'Monkeylogic Bit 5';

% By default set all to Input
set(dIO(:),'Direction','Input')

% Separate Device for triggers, in this case they are non-clocked
% operations (hence the IsNotifyWhenScansQueuedBelowAuto is off). This
% should generate a warning about clocked operations on most X series. 
niTrig = daq.createSession('ni');
niTrig.IsNotifyWhenScansQueuedBelowAuto = false;
niTrig.NotifyWhenScansQueuedBelow = 1;
% Port1 == PFI1
dTrig = niTrig.addDigitalChannel(devID,{'Port1/Line1:4'},'OutputOnly');
dTrig(1).Name = 'Q-Imaging Wide-field CCD Trigger';
dTrig(2).Name = 'PointGrey Whisker Tracking Trigger';
dTrig(3).Name = 'Mightex Eye Tracking Trigger'; % Save for future
dTrig(4).Name = 'none'; % Save for future use

% Add Counter Channels / names for documentation
%   CTR 3 A - PFI 5
%   CTR 3 Z - PFI 6
%   CTR 3 B - PFI 7
cIBall = niIn.addCounterInputChannel(devID,[3],'Position');
cIBall.EncoderType = 'X1';
cIBall(1).Name = 'Ball Quadrature';

% Counter for the strobe off the Mightex Camera -- potentially unused
% CTR 0 'EdgeCount' - PFI8
cICam = niIn.addCounterInputChannel(devID,[0],'EdgeCount');
cICam(1).Name = 'Mightex Eye Tracking Strobe Count';

%--------------------------------------------------------------------------
%-Optional daq devices: camera triggers + timing functions etc-------------
%--------------------------------------------------------------------------

% Use timer function for the CCD, needs to agree with the rates in software
if triggerQimagingCCD
    qImagingTriggerPort = 1;
    qImagingTriggerVerbose = 0;
    tFCCD = timer('ExecutionMode','fixedDelay','BusyMode','queue','Period',1/qImagingCCDRateHz);
    tFCCD.StartDelay = 2;
    tFCCD.TimerFcn = {@sendAcqTrigger,niTrig,qImagingTriggerPort,qImagingTriggerVerbose};
end

% Use timer functions to send +5V triggers to start PTGrey camera (Mode 15)
if triggerPtGreyCam
    ptGreyTriggerPort = 2;
    ptGreyTriggerVerbose = 0;
    tFptGrey = timer('ExecutionMode','singleShot','BusyMode','queue');
    tFptGrey.StartDelay = 2;
    tFptGrey.TimerFcn = {@sendAcqTrigger,niTrig,ptGreyTriggerPort,ptGreyTriggerVerbose};
end

% Use timer functions to send +5V triggers to Mightex camera @ some rate
if triggerMightexCam
    mightexTriggerPort = 3;
    mightexTriggerVerbose = 0;
    tFCam = timer('ExecutionMode','fixedDelay','BusyMode','queue','Period',1/mightexCameraRateHz);
    tFCam.StartDelay = 2;
    tFCam.TimerFcn = {@sendAcqTrigger,niTrig,mightexTriggerPort,mightexTriggerVerbose};
end

%% Running 

%--------------------------------------------------------------------------
%-Begin / end acquisition using timer funcitons----------------------------
%--------------------------------------------------------------------------
% Simple pause to start acquisition
fprintf('====================================\n')
fprintf('Start Acquisition With Any Key Press\n')
fprintf('====================================\n')
pause();

% Acquisition will quit using timer function prompts
niIn.startBackground();
fprintf('Acquisition started.\n')

% Start checking for acquisition termination and sending triggers, all of
% which have start delays and will not collide with an error.
if triggerQimagingCCD;  start(tFCCD);   end
if triggerPtGreyCam;    start(tFptGrey);end
if triggerMightexCam;   start(tFCam);   end
if (triggerQimagingCCD || triggerPtGreyCam || triggerMightexCam)
    fprintf('Trigger(s) started.\n')
end
fprintf('\n')

continueExp = 1;
while continueExp
    pause(2)
    userInput = input(['Stop Acquisition By Entering Q/q/E/e: '],'s');
    if ~isempty(userInput) && (sum([lower(userInput) == 'qe']) > 0)
        continueExp = 0;
    end
end 

stop(timerfindall)
delete(timerfindall)
niIn.stop;

[~] = fclose(logFileID);

%% Save / Cleanup

% Display savepaths / filenames
fprintf('\nAcquisition complete.\n')
fprintf('\tdaqSaveDir: %s\n', daqSaveDir);
fprintf('\tdaqLogFile: ..%s%s\n\n', filesep, daqSaveFile);

% Load in data and save as mat file for lab compatability
fprintf('Loading logged data into workspace... ')

logFileID = fopen(fullfile(daqSaveDir,daqSaveFile),'r');

nDaqChans = numel(dIO) + numel(aI) + numel(cIBall) + numel(cICam);
exp.Data = fread(logFileID,'double');
exp.Data = reshape(exp.Data,nDaqChans+1,[]);
exp.Count = exp.Data(1,:);
exp.Data = exp.Data(2:end,:);
[~] = fclose(logFileID);

exp.daqRate     = niIn.Rate;
exp.daqInIDs    = {niIn.Channels(:).ID};
exp.daqInNames  = {niIn.Channels(:).Name};

save(fullfile(daqSaveDir,matSaveFile),'exp','-v7.3');
fprintf('saved as .mat file.\n')
fprintf('\tdaqMatFile: ..%s%s\n\n', filesep, matSaveFile);
