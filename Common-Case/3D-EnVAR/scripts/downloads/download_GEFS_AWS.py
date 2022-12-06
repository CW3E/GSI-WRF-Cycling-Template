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
# and the max forecast hour for any zero hour.
#
# NOTE: as of 2022-10-15 AWS api changes across date ranges, syntax switches
# for dates between:
#
#     2017-01-01 to 2018-07-26
#     2018-07-27 to 2020-09-22
#     2020-09-23 to PRESENT
#
# the exclude statements in the below are designed to handle these exceptions
# using a recurisive copy from a base path.
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
from download_utilities import PROJ_ROOT, STR_INDT, get_reqs

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# starting date and zero hour of data
START_DATE = '2021-01-21T18:00:00'

# final date and zero hour of data
END_DATE = '2021-01-28T18:00:00'

# interval of forcast data outputs after zero hour
FCST_INT = 3

# number of hours between zero hours for forecast data
CYCLE_INT = 6

# max forecast lenght in hours
MAX_FCST = 6

# root directory where date stamped sub-directories will collect data downloads
DATA_ROOT = PROJ_ROOT +\
    '/GSI-WRF-Cycling-Template/Common-Case/3D-EnVAR/data/static/gribbed/GEFS'

##################################################################################
# UTILITY METHODS
##################################################################################

CMD = 'aws s3 cp --no-sign-request s3://noaa-gefs-pds/gefs.'

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
    print('Downloading GEFS Date ' + date.strftime('%Y-%m-%d') + '\n')
    print('Zero Hour ' + date.strftime('%H') + '\n')

    down_dir = DATA_ROOT + '/' + date.strftime('%Y%m%d') + '/'
    os.system('mkdir -p ' + down_dir)

    for fcst in fcst_reqs:
        # the following are the two and three digit padding versions of the hours
        HH  = fcst.zfill(2)
        HHH = fcst.zfill(3)
        print(STR_INDT + 'Forecast Hour ' + HH + '\n')
        cmd = CMD + date.strftime('%Y%m%d') + '/' + date.strftime('%H') + ' ' +\
              down_dir + ' ' +\
              '--recursive ' +\
              '--exclude \'*\'' + ' ' +\
              '--include \'*f' + HH + '\' '  +\
              '--include \'*f' + HHH + '\' '  +\
              '--exclude \'*chem*\'' + ' ' +\
              '--exclude \'*wave*\'' + ' ' +\
              '--exclude \'*geavg*\'' + ' ' +\
              '--exclude \'*gespr*\'' + ' ' +\
              '--exclude \'*gep*\'' + ' ' +\
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

print('\n')
print('Script complete -- verify the downloads at root ' + DATA_ROOT + '\n')

##################################################################################
# end
