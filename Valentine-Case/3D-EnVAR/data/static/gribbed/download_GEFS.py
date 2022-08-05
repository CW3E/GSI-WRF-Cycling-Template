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
from datetime import date, timedelta

##################################################################################
# SET GLOBAL PARAMETERS 

START_DATE = "2019-02-07"
END_DATE = "2019-02-16"
HOUR_INT = 6
MAX_FCST = 18
DATA_ROOT = "/cw3e/mead/projects/cwp130/scratch/cgrudzien/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR/data/static/gribbed"


##################################################################################
# UTILITY METHODS

str_indt = "    "

def get_reqs(start_date, end_date, hour_int, max_fcst):
    # generates requests based on script parameters
    date_reqs = []
    hour_reqs = []
    dates_range = max([int((end_date - start_date).days) + 1])
    hour_steps = int(max_fcst / hour_int)


    for n in range(0, dates_range):
        date_reqs.append((start_date + timedelta(n)).strftime('%Y%m%d'))

    for i in range(hour_steps + 1):
        hour_reqs.append(str(i * hour_int).zfill(2))

    return date_reqs, hour_reqs


##################################################################################
# download data

# define date range to get data
start_date = date.fromisoformat(START_DATE)
end_date = date.fromisoformat(END_DATE)

# obtain combinations
date_reqs, hour_reqs = get_reqs(start_date, end_date, HOUR_INT, MAX_FCST)

# define the zero hours for forecasts
hour_steps = int(24 / HOUR_INT)
hour_steps = [ str(i * HOUR_INT).zfill(2) for i in range(hour_steps)]

# make requests
for date in date_reqs:
    print("Downloading GEFS Date " + date + "\n")

    down_dir = DATA_ROOT + "/" + date + "/"
    print(str_indt + "Making download directory " + down_dir + "\n") 
    os.system("mkdir -p " + down_dir)

    for zH in hour_steps:
        print(str_indt + "Initialization Hour " + zH + "\n")

        for HH in hour_reqs:
            print(str_indt * 2 + "Forecast Hour " + HH + "\n")

            # download primary variables
            cmda = "aws s3 cp --no-sign-request " +\
                   "s3://noaa-gefs-pds/gefs." + date +\
                   "/" + zH +\
                   "/pgrb2a/ " + down_dir +\
                   " --exclude \"*\" --include \"*f" + HH + "\" --recursive"

            print(str_indt * 2 + "Running command:\n")
            print(str_indt * 3 + cmda + "\n")
            os.system(cmda)

            # download secondary variables
            cmdb = "aws s3 cp --no-sign-request " +\
                   "s3://noaa-gefs-pds/gefs." + date +\
                   "/" + zH +\
                   "/pgrb2b/ " + down_dir +\
                   " --exclude \"*\" --include \"*f" + HH + "\" --recursive"

            print(str_indt * 2 + "Running command:\n")
            print(str_indt * 3 + cmdb + "\n")
            os.system(cmdb)


print("\n")
print("Script complete -- verify the downloads at root " + DATA_ROOT + "\n")
