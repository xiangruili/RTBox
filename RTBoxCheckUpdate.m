function varargout = RTBoxCheckUpdate()
% RTBox_checkUpdate
%  Check if new version of driver code and firmware are available at Github. 
%  This requires internet connection.

% 160122 Xiangrui Li wrote it
% 180710 rewrite for update from github 

fileDate = getVersion();
if nargout, varargout{1} = fileDate; return; end

verLink = 'https://github.com/xiangruili/RTBox/blob/master/README.md';
try
    str = webread(verLink);
catch me
    try
        str = urlread(verLink);
    catch
        str = sprintf('%s.\n\nPlease download manually.', me.message);
        errordlg(str, 'Web access error');
        web('https://github.com/xiangruili/RTBox', '-browser');
        return;
    end
end

gitDate = getVersion(str);
if datenum(fileDate, 'yyyymmdd') >= datenum(gitDate, 'yyyymmdd')
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
    pth = fileparts(mfilename('fullpath'));
    copyfile([tdir '/RTBox-master/*.*'], [pth '/.'], 'f');
    rmdir(tdir, 's');
    fprintf(' RTBox driver updated.\n');
    cln = onCleanup(@rehash);
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

%% Ger version in README.md
function dStr = getVersion(str)
dStr = '20200408';
if nargin<1 || isempty(str)
    pth = fileparts(mfilename('fullpath'));
    fname = fullfile(pth, 'README.md');
    if ~exist(fname, 'file'), return; end
    str = fileread(fullfile(pth, 'README.md'));
end
a = regexp(str, 'version\s(\d{4}\.\d{2}\.\d{2})', 'tokens', 'once');
if ~isempty(a), dStr = a{1}([1:4 6:7 9:10]); end