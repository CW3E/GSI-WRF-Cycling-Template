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
#    'use'    : Use = asm: used in GSI analysis
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
# Imports
##################################################################################
import numpy as np
import pandas as pd
import pickle
import copy
import glob
from datetime import datetime as dt
from gsi_py_utilities import USR_HME, STR_INDT, get_anls
import os

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flow to analyze 
CTR_FLW = '3denvar_lag00_b1.00'

# define the case-wise sub-directory
CSE = 'VD'

# starting date and zero hour of data
START_DT = '2019-02-09T00:00:00'

# final date and zero hour of data
END_DT = '2019-02-15T00:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 6

# define domains to process
MAX_DOM = 1

# the string extension of the GSI fort diagnostic file
FORT='201'

##################################################################################
# Process data
##################################################################################
# define derived data paths
cse = CSE + '/' + CTR_FLW
data_root = USR_HME + '/data/simulation_io' + '/' + cse
out_dir = USR_HME + '/data/analysis' + '/' + cse + '/GSI_analysis'
os.system('mkdir -p ' + out_dir)

# convert to date times
start_dt = dt.fromisoformat(START_DT)
end_dt = dt.fromisoformat(END_DT)

# define the output name
out_path = out_dir + '/GSI_fort_' + FORT + '_' + START_DT +\
           '_to_' + END_DT + '.bin'

# generate the date range for the analyses
analyses = get_anls(start_dt, end_dt, CYCLE_INT)

# initiate empty dataframe / dictionary
d0 = pd.DataFrame.from_dict({
    'date'  : [],
    'iter'  : [],
    'use'   : [],
    'count' : [],
    'bias'  : [],
    'rms'   : [],
    'cpen'  : [],
    'qcpen' : [],
    })

for i in range(1, MAX_DOM + 1):
    # define a new dictionary for each domain
    exec('d0%s = copy.copy(d0)'%i)

    print('Processing domain d0%s'%i)

    # define the line index for the dataframe
    step = 0
    
    for (anl_date, anl_strng) in analyses:
        # open file and loop lines
        in_path = data_root + '/' + anl_strng + '/gsiprd/d0' + str(i) + '/fort.' + FORT
        print(STR_INDT + 'Opening file ' + in_path)
        f = open(in_path)

        for line in f:
            split_line = line.split()
            try:
                typ = split_line[3]
                if typ == 'all':
                    step += 1
                    tmp_dict = {
                        'date' : [anl_date],
                        'iter'  : [int(split_line[1])],
                        'use'   : [split_line[2]],
                        'count' : [int(split_line[4])],
                        'bias'  : [float(split_line[5])],
                        'rms'   : [float(split_line[6])],
                        'cpen'  : [float(split_line[7])],
                        'qcpen' : [float(split_line[8])],
                        }
                    exec('tmp_dict[\'step\'] = [int(step)]')
                    tmp_dict = pd.DataFrame.from_dict(tmp_dict, orient='columns')
                    exec('d0%s = pd.concat([d0%s, tmp_dict], axis=0)'%(i,i))

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
