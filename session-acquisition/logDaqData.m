function logDaqData(~,evt,fid)
    % write to file
    %data = evt.Data';
    %disp(size(data))
    
    data = [evt.TimeStamps, evt.Data]';
    fwrite(fid,data,'double');
end