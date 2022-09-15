##################################################################################
# Description
##################################################################################
# This script is a re-write of the GSI utility filter_fort220.ksh
# to be used with a companion re-write of GSI_cost_gradient.ncl in Python.
# This revision to a Python-based utility is for general extenability of the
# methods and for batch processing of time series of analyses.
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
# imports
import numpy as np
import pandas as pd
import pickle
import copy
import datetime

##################################################################################
# SET GLOBAL PARAMETERS 

# set paths to I/O
PROJ_DIR = '/cw3e/mead/projects/cwp130/scratch/cgrudzien/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR'
DATA_ROOT = PROJ_DIR + '/data/cycle_io'
OUT_DIR = PROJ_DIR + '/data/analysis'

# starting date and zero hour of data
START_DATE = '2019-02-11T00:00:00'

# final date and zero hour of data
END_DATE = '2019-02-11T00:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 6

# define domains to process
MAX_DOM = 1

##################################################################################
# UTILITY METHODS

str_indt = '    '

def get_anls(start_date, end_date, cycle_int):
    # generates analysis times based on script parameters
    anl_dates = []
    delta = end_date - start_date
    hours_range = delta.total_seconds() / 360
    fcst_steps = int(max_fcst / fcst_int)

    if cycle_int == 0 or delta.total_seconds() == 0:
        # for a zero cycle interval or start date equal end date, only process 
        # start date / hour directory
        anl_dates.append([start_date.strftime('%Y%m%d%H'))

    else:
        # define the analysis time over range of cycle intervals
        cycle_steps = int(hours_range / cycle_int)
        for i in range(cycle_steps + 1):
            anl_start = start_date + timedelta(hours=(i * cycle_int))
            anl_dates.append(anl_start.strftime('%Y%m%d%H'))

    return anl_dates


##################################################################################
# Process data

# generate the date range for the analyses
anl_dates = get_anls(start_date, end_date, cycle_int):

# initiate empty dataframe / dictionary
d0 = pd.DataFrame.from_dict({
    'date' : [],
    'iter' : [],
    'step' : [],
    'cost' : [],
    'grad' : [],
    })

for i in range(1, MAX_DOM + 1):
    # define a new dictionary for each domain
    exec('d0%s = copy.copy(d0)'%i)

    # define the line index for the dataframe
    step = 1
    
    for anl in anl_dates:
        # open file and loop lines
        in_path = DATA_ROOT + '/' + anl + '/gsiprd/d0' + str(i) + '/fort.220'
        f = open(in_path)

        for line in f:
            split_line = line.split(',')
            prefix = split_line[0]
            if prefix == 'cost':
               split_line = split_line[-1].split() 
                # process domain updates within MAX_DOM
                    if split_line[4:6] == ['dpsdt,', 'dmudt']:
                        tmp = np.array(split_line[7:])
                        tmp_dict = {
                            'wrf_time' : [date_time],
                            'xtime'    : [float(tmp[0])],      
                            'dpsdt'    : [float(tmp[1])],
                            'dmudt'    : [float(tmp[2])], 
                            }
                        exec('tmp_dict[\'step\'] = [int(d0%s_indx)]'%i)
                        tmp_dict = pd.DataFrame.from_dict(tmp_dict, orient='columns')
                        exec('d0%s = pd.concat([d0%s, tmp_dict], axis=0)'%(i,i))
                        exec('d0%s_indx += 1'%i)
    
f.close()
data = {}

for i in range(1, MAX_DOM + 1):
    exec('d0%s[\'step\'] = d0%s[\'step\'].astype(int)'%(i,i))
    exec('d0%s = d0%s.set_index(\'step\')'%(i,i))
    exec('data[\'d0%s\'] = d0%s'%(i,i))

f = open(OUT_PATH, 'wb')
pickle.dump(data, f)
f.close()

