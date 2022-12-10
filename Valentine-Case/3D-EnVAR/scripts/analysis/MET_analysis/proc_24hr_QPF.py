##################################################################################
# Description
##################################################################################
# This script reads in grid_stat_* files from a MET analysis and creates a Pandas
# dataframe containing a time series versus lead time to a verification period.
# The dataframes are saved into a Pickled dictionary organized by MET file
# extension
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
from py_plt_utilities import STR_INDT, get_anls, PROJ_ROOT

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flow to analyze 
CTR_FLW = 'deterministic_forecast_early_start_date_test'

# starting date and zero hour of forecast cycles
START_DATE = '2019-02-11T00:00:00'

# final date and zero hour of data of forecast cycles
END_DATE = '2019-02-14T00:00:00'

# valid date for the verification
VALID_DATE = '2019-02-15T00:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 24

##################################################################################
# Process data
##################################################################################
# define derived data paths 
data_root = PROJ_ROOT + '/data/analysis/' + CTR_FLW + '/MET_analysis'

# convert to date times
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)
valid_date = dt.fromisoformat(VALID_DATE)

# define the output name
out_path = data_root + '/grid_stats_lead_' + START_DATE +\
           '_to_' + END_DATE + '_valid_' + VALID_DATE +\
           '.bin'

# generate the date range for the analyses
analyses = get_anls(start_date, end_date, CYCLE_INT)

# initiate empty dictionary for storage of dataframes by keyname
data_dict = {}

print('Processing dates ' + START_DATE + ' to ' + END_DATE)
for (anl_date, anl_strng) in analyses:
    # define the gridstat files to open based on the analysis date
    in_paths = data_root + '/' + anl_strng + '/grid_stat_*.txt'

    # loop sorted grid_stat_* files
    in_paths = sorted(glob.glob(in_paths))
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
                tmp_dict[cols[i]] = split_line[i]

            tmp_dict['step'] = [int(df_indx)]
            tmp_dict = pd.DataFrame.from_dict(tmp_dict, orient='columns')
            fname_df = pd.concat([fname_df, tmp_dict], axis=0)
            df_indx += 1
        
        fname_df = fname_df.set_index('step')

        if postfix in data_dict.keys():
            data_dict[postfix] = pd.concat([data_dict[postfix], fname_df], axis=0)

        else:
            data_dict[postfix] = fname_df

        print(STR_INDT + 'Closing file ' + in_path)
        f.close()

print('Writing out data to ' + out_path)
f = open(out_path, 'wb')
pickle.dump(data_dict, f)
f.close()

##################################################################################
# end
