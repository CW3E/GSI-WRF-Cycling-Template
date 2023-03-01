##################################################################################
# Description
##################################################################################
# This script reads in arbitrary grid_stat_* output files from a MET analysis
# and creates Pandas dataframes containing a time series for each file type
# versus lead time to a verification period. The dataframes are saved into a
# Pickled dictionary organized by MET file extension as key names, taken
# agnostically from bash wildcard patterns.
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
from datetime import timedelta
from py_plt_utilities import STR_INDT, get_anls, USR_HME

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flow to analyze 
CTR_FLW = 'GFS'

# define the case-wise sub-directory
CSE = 'VD'

# verification domain for the forecast data                                                                           
GRD = '0.25'

# define the interpolation method and related parameters
INT_SHPE = 'SQUARE'
INT_MTHD = 'BUDGET'
INT_WDTH = '3'

# starting date and zero hour of forecast cycles
START_DT = '2019-02-08T00:00:00'

# final date and zero hour of data of forecast cycles
END_DT = '2019-02-14T00:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 24

# optionally define an output prefix based on settings
PRFX = INT_SHPE + '_' + INT_MTHD + '_' + INT_WDTH

##################################################################################
# Process data
##################################################################################
# define derived data paths 
cse = CSE + '/' + CTR_FLW
data_root = USR_HME + '/data/analysis/' + cse + '/MET_analysis'

# convert to date times
start_dt = dt.fromisoformat(START_DT)
end_dt = dt.fromisoformat(END_DT)

# define the output name
out_path = data_root + '/grid_stats_' + PRFX + '_' + GRD + '_' + START_DT +\
           '_to_' + END_DT + '.bin'

# generate the date range for the analyses
analyses = get_anls(start_dt, end_dt, CYCLE_INT)

# initiate empty dictionary for storage of dataframes by keyname
data_dict = {}

print('Processing dates ' + START_DT + ' to ' + END_DT)
for (anl_date, anl_strng) in analyses:
    # define the gridstat files to open based on the analysis date
    in_paths = data_root + '/' + anl_strng + '/' + GRD + '/grid_stat_' + PRFX + '*.txt'

    # loop sorted grid_stat_* files, sorting compares first on the length of lead time
    # for non left-padded values
    in_paths = sorted(glob.glob(in_paths), key=lambda x:(len(x.split('_')[-4]), x))
    for in_path in in_paths:
        print(STR_INDT + 'Opening file ' + in_path)

        # cut the diagnostic type from file name
        fname = in_path.split('/')[-1]
        split_name = fname.split('_')
        postfix = split_name[-1].split('.')
        postfix = postfix[0]

        # open file, load column names, then loop lines
        f = open(in_path)
        cols = f.readline()
        cols = cols.split()
        
        fname_df = {} 
        tmp_dict = {}
        df_indx = 1

        print(STR_INDT + 'Loading columns:')
        for col_name in cols:
            print(STR_INDT * 2 + col_name)
            fname_df[col_name] = [] 

        fname_df =  pd.DataFrame.from_dict(fname_df, orient='columns')

        # parse file by line, concatenating columns
        for line in f:
            split_line = line.split()

            for i in range(len(split_line)):
                val = split_line[i]

                # filter NA vals
                if val == 'NA':
                    val = np.nan
                tmp_dict[cols[i]] = val

            tmp_dict['line'] = [df_indx]
            tmp_dict = pd.DataFrame.from_dict(tmp_dict, orient='columns')
            fname_df = pd.concat([fname_df, tmp_dict], axis=0)
            df_indx += 1

        fname_df['line'] = fname_df['line'].astype(int)
        
        if postfix in data_dict.keys():
            last_indx = data_dict[postfix].index[-1]
            fname_df['line'] = fname_df['line'].add(last_indx)
            fname_df = fname_df.set_index('line')
            data_dict[postfix] = pd.concat([data_dict[postfix], fname_df], axis=0)

        else:
            fname_df = fname_df.set_index('line')
            data_dict[postfix] = fname_df


        print(STR_INDT + 'Closing file ' + in_path)
        f.close()

print('Writing out data to ' + out_path)
f = open(out_path, 'wb')
pickle.dump(data_dict, f)
f.close()

##################################################################################
# end
