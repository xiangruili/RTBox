function varargout = RTBoxCheckUpdate(mfile)
% RTBox_checkUpdate
%  Check whether new version of driver code and/or firmware are available at
%  RTBox website, and if so, ask user to update. 
% 
%  This requires internet connection.

% Require following special format/name for the web page:
%  '(updated mm/dd/yyyy'
%  'the latest firmware, v1.9, v4.6, v5.1, v... for download'
%  Firmware hex file must be in format downloads/RTBOX46.hex  

% 160122 Xiangrui Li wrote it
% 160915 Make it work for different zip names and different website folder.

if nargin<1, mfile = 'RTBox'; end
fileDate = {reviseDate(mfile) reviseDate('RTBoxPorts')};
fileDate = sort(fileDate); fileDate = fileDate{end};
if nargout, varargout{1} = fileDate; return; end % yymmdd
fileDate = datenum(fileDate, 'yymmdd');

str = urlread('http://lobes.osu.edu/rt-box.php');
ind = strfind(str, ' (updated ');
if isempty(ind), error('Error in reading RTBox website.'); end

latestStr = str(ind(1)+10:ind(1)+19);
latestNum = datenum(latestStr, 'mm/dd/yyyy');
doDriver = fileDate < latestNum;

try
    i1 = strfind(str, 'the latest firmware, '); i1 = i1(end);
    i2 = strfind(str(i1:end), 'for download') + i1 - 2;
    vs = str(i1+20:i2(1));
    vs = regexp(vs, 'v\d+\.?\d*|-v\d+\.?v\d*|\.?v\d*', 'match');
    vs = strrep(vs, 'v', '');
    vn = str2double(vs);

    [p, v] = RTBoxPorts(1);
    if isempty(p), error('No RTBox hardware detected.');
    elseif numel(p)>1, v = v(1);
    end
    i = floor(vn)==floor(v);
    vs = vs{i};
    doFirmware = vn(i)>v;
catch
    doFirmware = false;
end

if ~doDriver && ~doFirmware
    msgbox('Both RTBox driver and firmware are up to date.', 'Check update');
    return;
end

if doDriver
    msg = ['Update RTBox driver to the newer version (' latestStr ')?'];
    answer = questdlg(msg, 'Update RTBox driver', 'Yes', 'Later', 'Yes');
    if strcmp(answer, 'Yes')
        i1 = strfind(str(1:ind), 'href="'); % link to zip file
        i1 = i1(end) + 6; % start of zip file name
        i2 = strfind(str(i1:end), '.zip"');
        i2 = i2(1) + i1 + 2;
        remoteName = str(i1:i2);
        
        zipName = fullfile(tempdir, remoteName);
        try
            urlwrite(['http://lobes.osu.edu/' remoteName], zipName);
            unzip(zipName, fileparts(which(mfile)));
        catch me
            errordlg(['Error in updating: ' me.message], mfile);
            return;
        end
        rehash;
    end
end

if doFirmware
    msg = ['Update RTBox firmware to the newer version (v' vs ')?'];
    answer = questdlg(msg, 'Update RTBox firmware', 'Yes', 'Later', 'Yes');
    if ~strcmp(answer, 'Yes'), return; end

    hexFile = ['RTBOX' strrep(vs, '.', '') '.hex'];
    fname = fullfile(tempdir, hexFile);
    try
        urlwrite(['http://lobes.osu.edu/' hexFile], fname);
    catch me
        errordlg(['Error in updating: ' me.message], mfile);
        return;
    end
    RTBoxFirmwareUpdate(fname);
end

%% Get the last date string in history
function dStr = reviseDate(mfile)
if nargin<1, mfile = mfilename; end
dStr = '170509?';
fid = fopen(which(mfile));
if fid<1, return; end
str = fread(fid, '*char')';
fclose(fid);
str = regexp(str, '.*\n% (\d{6}) ', 'tokens', 'once');
if isempty(str), return; end
dStr = str{1};
%%
