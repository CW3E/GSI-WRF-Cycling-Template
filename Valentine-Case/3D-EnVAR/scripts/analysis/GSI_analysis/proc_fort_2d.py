##################################################################################
# Description
##################################################################################
# This script reads in a fort.* single level file from a GSI run and creates
# a Pandas dataframe containing time series values of the outputs of lines
#
#   o-g    0X    use    all    count    bias     rms    cpen    qcpen 
#
# giving summary statistics for the observations grouped into their 'use' as 
# assimilated, rejected or monitored.
#
# The dataframes are saved into a Pickled dictionary organized by fields as
#
#    'date'   : The cycle date time for which the analysis is performed 
#    'iter'   : Outer loop number = 01: observation - background 
#                                 = 02: observation - analysis (outer loop 1)
#                                 = 03: observation - analysis (outer loop 2)
#    'use'    : Use = assim: used in GSI analysis
#                   = mon: monitored (read in but not assimilated by GSI)
#                   = rej: rejected because of quality control in GSI
#    'count'  : Total number of observations of type 
#    'bias'   : Bias of observation departure for each outer loop
#    'rms'    : Root mean square error of observation departure for each outer loop 
#    'cpen'   : Observation part of penalty (cost function)
#    'qcpen'  : Nonlinear qc penalty
#
# Data input and output directories should be defined in the below along with
# DOM to control the domain processed.
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
import glob
from datetime import datetime as dt
from datetime import timedelta

##################################################################################
# SET GLOBAL PARAMETERS 

# set paths to I/O
PROJ_DIR = '/cw3e/mead/projects/cwp130/scratch/cgrudzien/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR'
DATA_ROOT = PROJ_DIR + '/data/cycle_io'
OUT_DIR = PROJ_DIR + '/data/analysis'

# starting date and zero hour of data
START_DATE = '2019-02-07T18:00:00'

# final date and zero hour of data
END_DATE = '2019-02-15T06:00:00'

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
# Process data

# convert to date times
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)

# define the output name
out_path = OUT_DIR + '/WRF_dps_dmu_dt_' + START_DATE +\
           '_to_' + END_DATE + '.txt'

# generate the date range for the analyses
analyses = get_anls(start_date, end_date, CYCLE_INT)

# initiate empty dataframe / dictionary
d0 = pd.DataFrame.from_dict({
    'step'     : [],
    'wrf_time' : [],
    'xtime'    : [],
    'dpsdt'    : [],
    'dmudt'    : [],
    'xgrid'    : [],
    'ygrid'    : [],
    'maxdmu'   : [],
    })

for i in range(1, MAX_DOM + 1):
    # define a new dictionary for each domain
    exec('d0%s = copy.copy(d0)'%i)

    # define the step index
    exec('d0%s_indx = 1'%i)

print('Processing dates ' + START_DATE + ' to ' + END_DATE)
for (anl_date, anl_strng) in analyses:
    # define the rsl.error.0000 file to open based on the analysis date
    in_path = DATA_ROOT + '/' + anl_strng + '/wrfprd/ens_00/rsl.wrf.*'

    # find the lexicographically last rsl directory based on run times
    in_path = sorted(glob.glob(in_path))[-1]
    in_path = in_path + '/rsl.error.0000'
    print(str_indt + 'Opening file ' + in_path)

    # open file and loop lines
    f = open(in_path)
    for line in f:
        split_line = line.split()
        prefix = split_line[0]
        if prefix == 'Timing':
            # update wrf_time handling exceptions
            try:
                t = split_line[6]
                date, time = t.split('_')
                date_time = pd.to_datetime(date + ' ' + time)
                print(2 * str_indt + str(date_time))
            except:
                pass
    
        elif prefix[:2] == 'd0':
            # process domain updates within MAX_DOM
            i = prefix[-1]
            if int(i) <= MAX_DOM:
                if split_line[4:6] == ['dpsdt,', 'dmudt']:
                    try:
                        tmp = np.array(split_line[7:])
                        tmp_dict = {
                            'wrf_time' : [date_time],
                            'xtime'    : [float(tmp[0])],      
                            'dpsdt'    : [float(tmp[1])],
                            'dmudt'    : [float(tmp[2])], 
                            }
                    except:
                        pass
    
                elif split_line[1:3] == ['Max', 'mu']:
                    try:
                        tmp = np.array(split_line[6:])
                        tmp_dict['xgrid'] = [float(tmp[0])]  
                        tmp_dict['ygrid'] = [float(tmp[1])] 
                        tmp_dict['maxdmu'] = [float(tmp[2])] 
                        exec('tmp_dict[\'step\'] = [int(d0%s_indx)]'%i)
                        tmp_dict = pd.DataFrame.from_dict(tmp_dict, orient='columns')
                        exec('d0%s = pd.concat([d0%s, tmp_dict], axis=0)'%(i,i))
                        exec('d0%s_indx += 1'%i)
                    except:
                        pass
    
    print(str_indt + 'Closing file ' + in_path)
    f.close()
data = {}

for i in range(1, MAX_DOM + 1):
    exec('d0%s[\'step\'] = d0%s[\'step\'].astype(int)'%(i,i))
    exec('d0%s = d0%s.set_index(\'step\')'%(i,i))
    exec('data[\'d0%s\'] = d0%s'%(i,i))

print('Writing out data to ' + out_path)
f = open(out_path, 'wb')
pickle.dump(data, f)
f.close()

