function startAcqWithInput(~,~,daqObj)
    %#ok<*NBRAK,*UNRCH>
    userInput = input('Start Acquisition With Any Letter. ','s');
    if sum([lower(userInput) == 'a':'z']) > 0
        fprintf('\tAcquisition Started.\n')
        daqObj.startBackground();
    else
        error('Acquisition Aborted.')
    end
end
