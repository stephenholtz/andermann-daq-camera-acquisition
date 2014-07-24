function logDaqData(~,evt,fid)
    % write to file
    data = [evt.TimeStamps, evt.Data]';
    fwrite(fid,data,'double');
end