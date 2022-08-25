##################################################################################
# License Statement:
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
# imports
import os, sys, ssl
import calendar
from datetime import datetime, timedelta

##################################################################################
# SET GLOBAL PARAMETERS 

# starting date and zero hour of data
START_DATE = '2019-02-11T00:00:00'

# final date and zero hour of data
END_DATE = '2019-02-11T00:00:00'

# interval of forcast data outputs after zero hour
FCST_INT = 6

# number of hours between zero hours for forecast data
CYCLE_INT = 6

# max forecast lenght in hours
MAX_FCST = 108

# root directory where date stamped sub-directories will collect data downloads
DATA_ROOT = '/cw3e/mead/projects/cwp130/scratch/cgrudzien/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data/static/gribbed'


##################################################################################
# UTILITY METHODS

str_indt = '    '

def get_reqs(start_date, end_date, fcst_int, cycle_int, max_fcst):
    # generates requests based on script parameters
    date_reqs = []
    fcst_reqs = []
    delta = end_date - start_date
    hours_range = delta.total_seconds() / 360
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
        fcst_reqs.append(str(i * fcst_int).zfill(2))

    return date_reqs, fcst_reqs


##################################################################################
# download data

## define date range to get data
start_date = datetime.fromisoformat(START_DATE)
end_date = datetime.fromisoformat(END_DATE)

# obtain combinations
date_reqs, fcst_reqs = get_reqs(start_date, end_date, FCST_INT,
                                CYCLE_INT, MAX_FCST)

# make requests
for date in date_reqs:
    print('Downloading GEFS Date ' + date[0] + '\n')
    print('Zero Hour ' + date[1] + '\n')

    down_dir = DATA_ROOT + '/' + date[0] + '/'
    os.system('mkdir -p ' + down_dir)

    for HH in fcst_reqs:
        print(str_indt + 'Forecast Hour ' + HH + '\n')

        # download primary variables
        cmda = 'aws s3 cp --no-sign-request ' +\
               's3://noaa-gefs-pds/gefs.' + date[0] +\
               '/' + date[1] +\
               '/pgrb2a/ ' + down_dir +\
               ' --exclude \'*\' --include \'*f' + HH + '\' --recursive'

        print(str_indt * 2 + 'Running command:\n')
        print(str_indt * 3 + cmda + '\n')
        os.system(cmda)

        # download secondary variables
        cmdb = 'aws s3 cp --no-sign-request ' +\
               's3://noaa-gefs-pds/gefs.' + date[0] +\
               '/' + date[1] +\
               '/pgrb2b/ ' + down_dir +\
               ' --exclude \'*\' --include \'*f' + HH + '\' --recursive'

        print(str_indt * 2 + 'Running command:\n')
        print(str_indt * 3 + cmdb + '\n')
        os.system(cmdb)


print('\n')
print('Script complete -- verify the downloads at root ' + DATA_ROOT + '\n')
