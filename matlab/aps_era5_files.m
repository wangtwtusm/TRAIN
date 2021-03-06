function [] = aps_era_files(orderflag_ECMWF_website)
% script that runs and checks which ERA5 data files are needed based on
% the satellite pass time from the ECMWF website.
% INPUTS:
%
%        ****** Specific for ECMWF data website ****** 
%        orderflag_ECMWF_website = 0/1 - no request(0)  (default(0)),
% 
%     This program is free software; you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation; either version 2 of the License, or
%     (at your option) any later version.
% 
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
% 
%     You should have received a copy of the GNU General Public License along
%     with this program; if not, write to the Free Software Foundation, Inc.,
%     51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
%
% By David Bekaert - June 2017
% Modifications:

stdargin = nargin ; 
if stdargin<1
    orderflag_ECMWF_website = 0;
end


% getting the variables from the parms_aps file
workdir = pwd;
stamps_processed = getparm_aps('stamps_processed');
UTC_sat =  getparm_aps('UTC_sat');
era5_datapath = getparm_aps('era_datapath');
datestructure = 'yyyymmdd';                               % assumed date structure for era
if isempty(era5_datapath)
    error('please specify era5_datapath')
end

% loading the data
if strcmp(stamps_processed,'y')
    ll_matfile = getparm_aps('ll_matfile');
    ps = load(ll_matfile);
    dates = ps.day;
else
    ifgday_matfile = getparm_aps('ifgday_matfile');
    ifgs_dates = load(ifgday_matfile);
    ifgs_dates = ifgs_dates.ifgday;
    dates = reshape(ifgs_dates,[],1);
    dates = unique(dates);
    dates = datenum(num2str(dates),'yyyymmdd');
end

% getting the dates
n_dates = length(dates);

% find two closest times with respect the 1hr spaced ERA5 data
n_step =1;	% hr time-step
timelist_ERA = ['0000' ; '0100';'0200';'0300';'0400' ;'0500';'0600' ;'0700';'0800';'0900';'1000' ;'1100'; '1200' ;'1300';'1400';'1500';'1600' ;'1700'; '1800' ;'1900';'2000';'2100';'2200' ;'2300'; '0000'];
time = str2num(UTC_sat(1:2)) + str2num(UTC_sat(4:5))/60;
t_before = floor(time/n_step);
t_after = ceil(time/n_step);
fprintf(['Satellite pass is ' num2str(time) ' UTC \n'])

% the fraction it is closer towards the other date.
f_after = (time - n_step*t_before)/(n_step*t_after - n_step*t_before);
f_after(isnan(f_after))=1;
f_before = 1-f_after;

% the time stamp of the closest two ERA5 acquisitions
time1 = num2str(timelist_ERA(t_before+1,:));
time2 = num2str(timelist_ERA(t_after+1,:));
% The date for the times after 2300 will change to the next day latter on
clear time
if floor(24/n_step)~=24/n_step
    error('Double check the time-step rounding to next day')
end

filelist = [];
datelist = [];
for d = 1:n_dates
    date = datestr(dates(d),datestructure);
    
    % Satellite pass is in the evening, next acqusition is next day
    date2= date;
    if t_after==24/n_step
        date2 = datestr(dates(d)+1,datestructure);
    end
        
    for t = 1:2
        if t == 1
            file = ['ggap' date time1 '.nc']; %Format ggapYYYYMMDDHHMM.nc
        end
        if t == 2
            file = ['ggap' date2 time2 '.nc']; %Format ggapYYYYMMDDHHMM.nc
        end
        filelist = [filelist ; file];
        datelist = [datelist ; date ; (date2)];
    end
end
filelist = unique(filelist,'rows');
datelist = unique(datelist,'rows');


% outputing this information to a file
fid = fopen('ERA5_files.txt','w');
fid2 = fopen('ERA5_dates.txt','w');
fprintf(['Required ERA5 files for all interferograms \n'])
for k=1:size(filelist,1)
    fprintf([filelist(k,:) '\n']);
    fprintf(fid,[filelist(k,:) '\n']);
end
fclose(fid);

for k=1:size(datelist,1)
    fprintf(fid2,[datelist(k,3:end) '\n']);
end
fclose(fid2);



%% Below is specific for the ECMWF data website
crop_range_in = 2; % increasing extent of weather data region by this value (degree)
overwrite_flag=-1;
if orderflag_ECMWF_website==1

    
    % weather model region
    fprintf('getting the data from the ECMWF service ...')
    region_lat_range = getparm_aps('region_lat_range');
    region_lon_range = getparm_aps('region_lon_range');
    if isempty(region_lat_range) == 1
        error('Specify the region for the weather model data')
    end
    fprintf('increasing crop area by %s deg in each direction \n',num2str(crop_range_in))
    S = num2str(min(round(region_lat_range)) - crop_range_in);
    N = num2str(max(round(region_lat_range)) + crop_range_in);
    W = num2str(min(round(region_lon_range)) - crop_range_in);
    E = num2str(max(round(region_lon_range)) + crop_range_in);       % DB fixed typo min to max  
    weatherregstr = [N,'/',W,'/',S,'/',E];   % N/W/S/E
    fprintf('weather model region N/W/S/E %s \n',weatherregstr);
    fprintf('using mars service from ECMWF downloading to \n %s \n',era5_datapath);
    % folder structure YYYYMMDD times within

    
    for l = 1:size(filelist,1)
        subdirpath = [era5_datapath,'/',filelist(l,5:12),'/'];
        if exist(subdirpath,'dir') == 0
            fprintf('creating directory %s \n',subdirpath);
            mkdir(subdirpath)
        end
        if exist([subdirpath,'ggap', filelist(l,5:16) '.nc'],'file') == 0
            cd(subdirpath)
            fprintf('Order and downloading %s \n',filelist(l,5:16))
            aps_era5_ECMWF_Python(filelist(l,5:16),weatherregstr) %write python donwload file
            python_str = ['python ',filelist(l,5:16),'.py > ',filelist(l,5:16),'down.log &'];
            [a,b] = system(python_str); % start python script
            clear a b
            cd ..
        else
            if overwrite_flag==-1
                str='';
                while ~strcmpi(str,'y') && ~strcmpi(str,'n') 
                    fprintf(['Do you want to overwrite existing files? \n'])  
                    str = input('[y: for yes, n: no] \n','s');
                end
                if strcmpi(str,'n')
                    overwrite_flag=0;
                else
                    overwrite_flag=1;
                end
            end
            % check if the files need to be overwritten
            if overwrite_flag==1
                cd(subdirpath)
                delete([subdirpath,'ggap', filelist(l,5:16) '.nc'])
                fprintf('Order and downloading %s \n',filelist(l,5:16))
                aps_era5_ECMWF_Python(filelist(l,5:16),weatherregstr) %write python donwload file
                python_str = ['python ',filelist(l,5:16),'.py > ',filelist(l,5:16),'down.log &'];
                [a,b] = system(python_str); % start python script
                clear a b
                cd ..
            elseif overwrite_flag==0
                fprintf('File %s has already been downloaded \n',filelist(l,:))
            end
        end
    end
    cd(workdir)
end
cd(workdir)     % back to work directory
    
