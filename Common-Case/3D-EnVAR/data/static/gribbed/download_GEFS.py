##################################################################################
# Description
##################################################################################
# This script is to automate downloading GEFS perturbation data for WRF
# initialization over arbitrary date ranges hosted by AWS, without using a
# sign-in to an account.  This data is hosted on the AWS open data service
# sponsored by NOAA at
#
#     https://registry.opendata.aws/noaa-gefs/
#
# Dates are specified in iso format in the global parameters for the script below.
# Other options specify the frequency of forecast outputs, time between zero hours
# and the max forecast hour for any zero hour.  GEFS control solution is not
# downloaded by default, though this can be modified by removing the line
#
#    '--exclude \'*gec*\'' + ' ' +\
#
# below.
#
# NOTE: as of 2022-10-15 AWS api changes across date ranges, syntax switches
# for dates between:
#
#     2017-01-01 to 2018-07-26
#     2018-07-27 to 2020-09-22
#     2020-09-23 to PRESENT
#
# the exclude statements in the below are designed to handle these exceptions
# using a recurisive copy from a base path.  Likewise, padding for forecast hours
# changes length and multiple include statements are supplied to handle
# discrepancies.  All data will be downloaded to a path of the form
#
#     DATA_ROOT/GEFS/YYYYMMDD/gepXX.tHHz.pgrb2a.fZZZ
#     DATA_ROOT/GEFS/YYYYMMDD/gepXX.tHHz.pgrb2b.fZZZ
#
# with the file names from AWS modified from their original form to match
# this convention for consistency with the workflow.
# 
##################################################################################
# License Statement:
##################################################################################
#
# Copyright 2022 Colin Grudzien, cgrudzien@ucsd.edu
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.
# 
##################################################################################
# Imports
##################################################################################
import os, sys, ssl
import calendar
import glob
from datetime import datetime as dt
from datetime import timedelta

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# starting date and zero hour of data
START_DATE = '2017-02-08T00:00:00'

# final date and zero hour of data
END_DATE = '2017-02-08T00:00:00'

# interval of forcast data outputs after zero hour
FCST_INT = 6

# number of hours between zero hours for forecast data
CYCLE_INT = 6

# max forecast lenght in hours
MAX_FCST = 6

# directory of git clone
PROJ_ROOT = '/cw3e/mead/projects/cwp106/scratch'

# root directory where date stamped sub-directories will collect data downloads
DATA_ROOT = PROJ_ROOT +\
    '/GSI-WRF-Cycling-Template/Common-Case/3D-EnVAR/data/static/gribbed/GEFS'


##################################################################################
# UTILITY METHODS
##################################################################################

STR_INDT = '    '
CMD = 'aws s3 cp --no-sign-request s3://noaa-gefs-pds/gefs.'

def get_reqs(start_date, end_date, fcst_int, cycle_int, max_fcst):
    # generates requests based on script parameters
    date_reqs = []
    fcst_reqs = []
    delta = end_date - start_date
    hours_range = delta.total_seconds() / 3600
    fcst_steps = int(max_fcst / fcst_int)

    if cycle_int == 0 or delta.total_seconds() == 0:
        # for a zero cycle interval or start date equal end date, only download
        # at start date / hour
        date_reqs.append([start_date.strftime('%Y%m%d'),
                          start_date.strftime('%H')])

    else:
        # define the zero hours for forecasts over range of cycle intervals
        cycle_steps = int(hours_range / cycle_int)
        for i in range(cycle_steps + 1):
            fcst_start = start_date + timedelta(hours=(i * cycle_int))
            date_reqs.append([fcst_start.strftime('%Y%m%d'),
                              fcst_start.strftime('%H')])

    for i in range(fcst_steps + 1):
        # download the forecast horizons in the range fcst_steps
        # NOTE: there is a syntax switch from 2 digit padding to three
        # digit padding so that we will create two versions of the forecast
        # request to make valid calls across dates
        fcst_reqs.append([str(i * fcst_int).zfill(2),
                          str(i * fcst_int).zfill(3)])

    return date_reqs, fcst_reqs


##################################################################################
# Download data
##################################################################################
# define date range to get data
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)

# obtain combinations
date_reqs, fcst_reqs = get_reqs(start_date, end_date, FCST_INT,
                                CYCLE_INT, MAX_FCST)

# make requests
for date in date_reqs:
    print('Downloading GEFS Date ' + date[0] + '\n')
    print('Zero Hour ' + date[1] + '\n')

    down_dir = DATA_ROOT + '/' + date[0] + '/'
    os.system('mkdir -p ' + down_dir)

    for fcst in fcst_reqs:
        # the following are the two and three digit padding versions of the hours
        HH = fcst[0]
        HHH = fcst[1]
        print(STR_INDT + 'Forecast Hour ' + HH + '\n')
        cmd = CMD + date[0] + '/' + date[1] + ' ' +\
              down_dir + ' ' +\
              '--recursive ' +\
              '--exclude \'*\'' + ' ' +\
              '--include \'*f' + HH + '\' '  +\
              '--include \'*f' + HHH + '\' '  +\
              '--exclude \'*chem*\'' + ' ' +\
              '--exclude \'*wave*\'' + ' ' +\
              '--exclude \'*geavg*\'' + ' ' +\
              '--exclude \'*gespr*\'' + ' ' +\
              '--exclude \'*gec*\'' + ' ' +\
              '--exclude \'*0p25*\''

        print(STR_INDT * 2 + 'Running command:\n')
        print(STR_INDT * 3 + cmd + '\n')
        os.system(cmd)

    # unpack data from nested directory structure, excluding the root
    print(STR_INDT + 'Unpacking files from nested directories')
    find_cmd = 'find ' + down_dir + ' -type f > file_list.txt'

    print(find_cmd)
    os.system(find_cmd)
              
    f = open('./file_list.txt', 'r')

    print(STR_INDT * 2 + 'Unpacking nested directory structure into ' + down_dir)
    for line in f:
        cmd = 'mv ' + line[:-1] + ' ' + down_dir
        os.system(cmd)

    # cleanup empty directories and file list
    f.close()

    find_cmd = 'find ' + down_dir + ' -type d > dir_list.txt'
    print(find_cmd)
    os.system(find_cmd)

    f = open('./dir_list.txt', 'r')
    print(STR_INDT * 2 + 'Removing empty nested directories')
    line_list = f.readlines()
    line_list = line_list[-1:0:-1]

    for line in line_list:
        os.system('rmdir ' + line)

    os.system('rm file_list.txt')
    os.system('rm dir_list.txt')

    # clean file names for consistency
    fnames = glob.glob(down_dir + '*')
    for name in fnames:
        split_name = name.split('.')
        
        if len(split_name) > 4:
            del split_name[3]

        else:
            pgrb, fcst_hr = split_name[-1].split('f')
            split_name[-1] = pgrb + '.f' + fcst_hr.zfill(3)

        tmp_name = ''
        for i in range(len(split_name) - 1):
            tmp_name += split_name[i] + '.'

        tmp_name += split_name[-1] 
        os.system('mv ' + name + ' ' + tmp_name)

print('\n')
print('Script complete -- verify the downloads at root ' + DATA_ROOT + '\n')

##################################################################################
# end
