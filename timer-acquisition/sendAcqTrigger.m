function sendAcqTrigger(~,~,daqTrigObj,daqChan,triggerVerbose)
    %#ok<*NBRAK,*UNRCH>
    
    % Generate the vector to send out on the trigger object
    emptyOut = zeros(1,numel(daqTrigObj.Channels));
    dataOut = emptyOut;
    dataOut(daqChan)= 1;
    
    % Send the trigger with two subsequent calls to outputSingleScan
    daqTrigObj.outputSingleScan(dataOut);
    daqTrigObj.outputSingleScan(emptyOut);
    
    if triggerVerbose
        % Note verbose will cause more collisions!
        fprintf('\tTrigger Sent on %s \n',daqTrigObj(1).Channels(daqChan).ID)
    end
end
