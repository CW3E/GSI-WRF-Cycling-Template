##################################################################################
# Description
##################################################################################
# This script reads in a generic fort.220 file from a GSI run and creates
# a Pandas dataframe containing time series values of the outputs of lines
#
#   cost,grad,step,b,step? = iter step cost grad  XX  XX  good
#
# giving time series statistics for the GSI cost diagnostics.
#
# The dataframes are saved into a Pickled dictionary organized by fields as
#
#    'date'   : The cycle date time for which the analysis is performed 
#    'loop'   : Outer loop number = 01 / 02 
#    'iter'   : Iteration of the cost function in the current outer loop
#    'cost'   : Eval of cost function in the current iteration / outer loop
#    'grad'   : Norm of the cost function gradient in the current iteration /
#               outer loop
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
from datetime import datetime as dt
from gsi_py_utilities import PROJ_ROOT, STR_INDT, get_anls
import os

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flow to analyze 
CTR_FLW = '3denvar_downscale'

# starting date and zero hour of data
START_DATE = '2019-02-08T00:00:00'

# final date and zero hour of data
END_DATE = '2019-02-08T06:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 6

# define domains to process
MAX_DOM = 1

##################################################################################
# Process data
##################################################################################
# define derived data paths
data_root = PROJ_ROOT + '/data/cycle_io' + '/' + CTR_FLW
out_dir = PROJ_ROOT + '/data/analysis' + '/' + CTR_FLW
os.system('mkdir -p ' + out_dir)

# convert to date times
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)

# define the output name
out_path = out_dir + '/GSI_cost_grad_anl_' + START_DATE +\
           '_to_' + END_DATE + '.bin'

# generate the date range for the analyses
analyses = get_anls(start_date, end_date, CYCLE_INT)

# initiate empty dataframe / dictionary
d0 = pd.DataFrame.from_dict({
    'date' : [],
    'loop' : [],
    'iter' : [],
    'cost' : [],
    'grad' : [],
    })

for i in range(1, MAX_DOM + 1):
    # define a new dictionary for each domain
    exec('d0%s = copy.copy(d0)'%i)

    print('Processing domain d0%s'%i)

    # define the line index for the dataframe
    step = 0
    
    for (anl_date, anl_strng) in analyses:
        # open file and loop lines
        in_path = data_root + '/' + anl_strng + '/gsiprd/d0' + str(i) + '/fort.220'
        print(STR_INDT + 'Opening file ' + in_path)
        f = open(in_path)

        for line in f:
            split_line = line.split(',')
            prefix = split_line[0]
            if prefix == 'cost':
                step += 1
                split_line = split_line[-1].split() 
                tmp = np.array(split_line[2:6])
                tmp_dict = {
                    'date' : [anl_date],
                    'loop' : [float(tmp[0])],      
                    'iter' : [float(tmp[1])],
                    'cost' : [float(tmp[2])], 
                    'grad' : [float(tmp[3])], 
                    }
                exec('tmp_dict[\'step\'] = [int(step)]')
                tmp_dict = pd.DataFrame.from_dict(tmp_dict, orient='columns')
                exec('d0%s = pd.concat([d0%s, tmp_dict], axis=0)'%(i,i))
    
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
