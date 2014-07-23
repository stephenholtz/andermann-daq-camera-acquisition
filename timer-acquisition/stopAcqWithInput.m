function stopAcqWithInput(~,~,daqObj)
    %#ok<*NBRAK,*UNRCH>
    userInput = input('Stop Acquisition By Entering Q/q/E/e: ','s');
    if sum([lower(userInput) == 'qe']) > 0
        fprintf('\tAcquisition ended.\n')
        daqObj.stop();
    end
end
