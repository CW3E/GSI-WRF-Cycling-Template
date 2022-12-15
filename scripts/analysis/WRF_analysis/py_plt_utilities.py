##################################################################################
# Description
##################################################################################
# This module contains utility methods for plotting and data analysis
# to be used separately from the wrf_py environment.
#
##################################################################################
# License Statement
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
from datetime import datetime as dt
from datetime import timedelta

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################

# standard string indentation
STR_INDT = "    "

# define location of git clone 
USR_HME = '/cw3e/mead/projects/cwp106/scratch/cgrudzien'

# define project space
PROJ_ROOT = USR_HME + '/GSI-WRF-Cycling-Template/Common-Case/3D-EnVAR'

##################################################################################
# UTILITY METHODS
##################################################################################
# generates analysis times based on script parameters

def get_anls(start_date, end_date, cycle_int):
    anl_dates = []
    anl_strng = []
    delta = end_date - start_date
    hours_range = delta.total_seconds() / 3600

    if cycle_int == 0 or delta.total_seconds() == 0:
        # for a zero cycle interval or start date equal end date, only process 
        # the start date time directory
        anl_dates.append(start_date)
        anl_strng.append(start_date.strftime('%Y%m%d%H'))

    else:
        # define the analysis times over range of cycle intervals
        cycle_steps = int(hours_range / cycle_int)
        for i in range(cycle_steps + 1):
            anl_date = start_date + timedelta(hours=(i * cycle_int))
            anl_dates.append(anl_date)
            anl_strng.append(anl_date.strftime('%Y%m%d%H'))

    return zip(anl_dates, anl_strng)

##################################################################################
# end
