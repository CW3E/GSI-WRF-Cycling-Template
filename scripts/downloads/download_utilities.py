##################################################################################
# Description
##################################################################################
# This module is designed to provide utility methods for the download scripts
# for NCEP and ECMWF datasets with common variables and routines.  Download
# scripts import the methods and global variable definitions below.
# 
##################################################################################
# License Statement:
##################################################################################
#
# Copyright 2023 CW3E, Contact Colin Grudzien cgrudzien@ucsd.edu
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
from datetime import datetime as dt
from datetime import timedelta

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# directory of git clone
USR_HME = '/cw3e/mead/projects/cwp106/scratch/GSI-WRF-Cycling-Template'

##################################################################################
# UTILITY METHODS
##################################################################################

STR_INDT = '    '

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
        date_reqs.append(start_date)

    else:
        # define the zero hours for forecasts over range of cycle intervals
        cycle_steps = int(hours_range / cycle_int)
        for i in range(cycle_steps + 1):
            fcst_start = start_date + timedelta(hours=(i * cycle_int))
            date_reqs.append(fcst_start)

    for i in range(fcst_steps + 1):
        # define strings of forecast hours, padd to necessary size in scripts
        fcst_reqs.append(str(i * fcst_int))

    return date_reqs, fcst_reqs

##################################################################################
# end
