##################################################################################
# Description
##################################################################################
# This script reads in a generic rsl.*.* file from a WRF run and creates a Pandas
# dataframe containing time series values of the outputs of lines
#
#     d0X   Domain average of dpsdt, dmudt (mb/3h): xtime dpsdt dmudt 
#     d0X   Max mu change time step: xgrid ygrid maxdmu 
#
# The dataframes are saved into a Pickled dictionary organized by domain number
# 'd0X', with the dataframe columns given as 
#
#    'step'      : integer time step of the simulation - domain specific
#    'wrf_time'  : the raw model hour of the simulation in datetime format
#    'xtime'     : total ellapsed minutes of model time in decimal form
#    'dpsdt'     : surface pressure tendency
#    'dmudt'     : mu tendency
#    'xgrid'     : max change in mu over grid -- corresponing x coordinate
#    'ygrid'     : max change in mu over grid -- corresponing y coordinate
#    'maxdmu'    : max change in mu over grid
#
# Data input and output directories should be defined in the below along with
# MAX_DOM to control the number of domains processed.  Testing on more than two
# domains is still pending.
#
##################################################################################
# License Statement
##################################################################################
#
# Copyright 2022 CW3E, Contact Colin Grudzien cgrudzien@ucsd.edu
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
import numpy as np
import pandas as pd
import pickle
import copy
import glob
from datetime import datetime as dt
from datetime import timedelta
from py_plt_utilities import STR_INDT, get_anls, USR_HME

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flow to analyze 
CTR_FLW = '3dvar_control'

# starting date and zero hour of data
START_DATE = '2021-01-21T18:00:00'

# final date and zero hour of data
END_DATE = '2021-01-28T18:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 6

# define domains to process
MAX_DOM = 1

##################################################################################
# Process data
##################################################################################
# define derived data paths 
data_root = USR_HME + '/data/simulation_io/' + CTR_FLW
out_dir = USR_HME + '/data/analysis/' + CTR_FLW + '/WRF_analysis'

# convert to date times
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)

# define the output name
out_path = out_dir + '/' + CTR_FLW + '_WRF_dps_dmu_dt_' + START_DATE +\
           '_to_' + END_DATE + '.bin'

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
    in_path = data_root + '/' + anl_strng + '/wrfprd/ens_00/rsl.wrf.*'

    # find the lexicographically last rsl directory based on run times
    in_path = sorted(glob.glob(in_path))[-1]
    in_path = in_path + '/rsl.error.0000'
    print(STR_INDT + 'Opening file ' + in_path)

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
                print(2 * STR_INDT + str(date_time))
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
    
    print(STR_INDT + 'Closing file ' + in_path)
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

##################################################################################
# end
