function sendAcqTrigger(~,~,daqObj,daqChan,triggerVerbose)
%#ok<*NBRAK,*UNRCH>
    if triggerVerbose
        fprintf('\tTrigger Sent, \n')
    end
    daqObj(daqChan)
end
