function varargout = RTBoxCheckUpdate()
% RTBox_checkUpdate
%  Check whether new version of driver code and/or firmware are available at
%  Github website, and if so, ask user to update. 
% 
%  This requires internet connection.

% 160122 Xiangrui Li wrote it
% 180710 rewrite for update from github 

pth = mfilename('fullpath');
pth = fileparts(pth);
str = fileread(fullfile(pth, 'Contents.m'));
fileDate = regexp(str, 'Version\s(\d{4}\.\d{2}\.\d{2})', 'tokens', 'once');
if nargout, varargout{1} = fileDate{1}; return; end
fileDate = datenum(fileDate{1}, 'yyyy.mm.dd');

str = webread('https://github.com/xiangruili/RTBox/blob/master/Contents.m');
v = regexp(str, 'Version\s(\d{4}\.\d{2}\.\d{2})', 'tokens', 'once');
latestNum = datenum(v, 'yyyy.mm.dd');
if fileDate >= latestNum
    fprintf(' RTBox driver is up to date.\n');
    return;
end

try    
    data = webread('https://github.com/xiangruili/RTBox/archive/master.zip');
    tmp = [tempdir 'RTBox.zip'];
    fid = fopen(tmp, 'w');
    fwrite(fid, data, 'uint8');
    fclose(fid);
    tdir = [tempdir 'tmp'];
    unzip(tmp, tdir); delete(tmp);
    copyfile([tdir '/RTBox-master/*.*'], [pth '/.'], 'f');
    rmdir(tdir, 's');
    fprintf(' RTBox driver updated.\n');
catch me
    fprintf(2, '%s\n', me.message);
    fprintf(2, [' Update failed. Please download driver at\n' ...
                '  https://github.com/xiangruili/RTBox\n']);
    return;
end

[p, v] = RTBoxPorts(1);
if isempty(p), error('No RTBox hardware detected.'); end
v = v(1);
nam = dir([pth '/doc/RTBOX' num2str(fix(v)) '*.hex']);
nam = nam(1).name;
vHex = str2double(nam(6:8)) / 100;
if vHex > v
    msg = ['Update RTBox firmware to the newer version (v' num2str(vHex) ')?'];
    answer = questdlg(msg, 'Update RTBox firmware', 'Yes', 'Later', 'Yes');
    if ~strcmp(answer, 'Yes'), return; end
    RTBoxFirmwareUpdate([pth '/doc/' nam]);
end

rehash;
