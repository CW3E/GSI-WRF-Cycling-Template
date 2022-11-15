##################################################################################
# Description
##################################################################################
# This script is the companion proc_fort_2d.py.  This will
# load the dataframe generated by the processing script and plot the time series
# of values for the 
# across the analysis times and the two outer-loops of the GSI analysis.
#
# The range of fort.220 files will be pre-processed into a Pandas dataframe
# and this plotting script should point to the output of the preprocessing script
# for the input file.
#
# The dataframes are saved into a Pickled dictionary organized by domain number
# 'd0X', with the dataframe columns given as 
#
#    'step' : Index of the number of GSI steps, from first analysis
#    'date' : Crurent analysis date time
#    'loop' : Outter-loop index for the optimization in GSI
#    'iter' : Iteration of the current loop in GSI
#    'cost' : Cost function return value in current iteration
#    'grad' : Gradient norm return value in the current iteration
#
# Data input and plot output directories should be defined in the below along
# with MAX_DOM to control the number of domains processed.  Testing on more
# than one domain is still pending.
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
import datetime
import matplotlib
# use this setting on COMET / Skyriver for x forwarding
matplotlib.use('TkAgg')
from matplotlib import pyplot as plt
from matplotlib.ticker import PercentFormatter
from gsi_py_utilities import PROJ_ROOT

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flow to analyze 
CTR_FLW = '3denvar_downscale'

# starting date and zero hour of data
START_DATE = '2019-02-08T00:00:00'

# final date and zero hour of data
END_DATE = '2019-02-08T06:00:00'

# define domain to plot
DOM = 1

# define the fort number to plot
FORT='201'

##################################################################################
# Begin plotting
##################################################################################
# define derived data paths
data_root = PROJ_ROOT + '/data/analysis' + '/' + CTR_FLW
in_path = data_root + '/GSI_fort_' + FORT + '_' + START_DATE + '_to_' +\
          END_DATE + '.bin'
out_path = data_root + '/GSI_fort_' + FORT + '_' + str(DOM) + '_' +\
           START_DATE + '_to_' + END_DATE + '.png'

# load and plot data
f = open(in_path, 'rb')
data = pickle.load(f)
f.close()

# load dataframe
exec('data = data[\'d0%s\']'%DOM)

# define two panel figure with pre-defined size
fig = plt.figure(figsize=(16,8))
ax1 = fig.add_axes([.110, .25, .85, .33])
ax0 = fig.add_axes([.110, .58, .85, .33])

# set colors and storage for looping
line_colors = ['#1b9e77', '#7570b3', '#d95f02', 'k']

# subset monitored data for clean rms calculation
bkg_mon = data.loc[(data['use'] == 'mon') & (data['iter'] == 1.0)]
anl_mon = data.loc[(data['use'] == 'mon') & (data['iter'] == 2.0)]

# subset assimilated data
bkg_asm = data.loc[(data['use'] == 'asm') & (data['iter'] == 1.0)]
anl_asm = data.loc[(data['use'] == 'asm') & (data['iter'] == 2.0)]

# subset rejected data
bkg_rej = data.loc[(data['use'] == 'rej') & (data['iter'] == 1.0)]
anl_rej = data.loc[(data['use'] == 'rej') & (data['iter'] == 2.0)]

# define looping index
index = len(bkg_asm['rms'].values)

# compute percent rejected
b_per_rej = np.zeros(index)
a_per_rej = np.zeros(index)
for i in range(index):
    b_num_mon = bkg_mon['count'].values[i]
    a_num_mon = anl_mon['count'].values[i]

    b_num_rej = bkg_rej['count'].values[i]
    a_num_rej = anl_rej['count'].values[i]

    b_num_asm = bkg_asm['count'].values[i]
    a_num_asm = anl_asm['count'].values[i]

    b_per_rej[i] = 100 * b_num_rej / (b_num_mon + b_num_rej + b_num_asm)
    a_per_rej[i] = 100 * a_num_rej / (a_num_mon + a_num_rej + a_num_asm)

# generate lines, saving values for legend
l0, = ax0.plot(range(index), bkg_asm['rms'], linewidth=2, markersize=26, color=line_colors[0])
l1, = ax0.plot(range(index), anl_asm['rms'], linewidth=2, markersize=26, color=line_colors[1])

l2, = ax1.plot(range(index), b_per_rej, linewidth=2, markersize=26, color=line_colors[2])
l3, = ax1.plot(range(index), a_per_rej, linewidth=2, markersize=26, color=line_colors[3])

line_list = [l0, l1, l2, l3]
line_labs = ['For RMSE', 'Anl RMSE', 'For % Rej', 'Anl % Rej']

dates = bkg_mon['date'].values
tic_mark = []
tic_labs = []

tic_count = 0
for i in range(0, index):
    tic_mark.append(i)

    if tic_count % 2 == 0:
        date_str = str(dates[i]).split(':')[0]
        tic_labs.append(date_str)

    else:
        tic_labs.append("")

    tic_count += 1

##################################################################################
# define display parameters

#plot bounds
ax0.set_xlim([-1,index])
ax1.set_xlim([-1,index])

ax0.set_xticks(tic_mark)
ax1.set_xticks(tic_mark, labels=tic_labs, rotation=45, ha='right')

# tick parameters
ax0.tick_params(
    labelsize=20,
    labelbottom=False,
    )

ax1.tick_params(
    labelsize=20,
    )

ax1.yaxis.set_major_formatter(PercentFormatter(decimals=0))

# add legend and sub-titles
fig.legend(line_list, line_labs, fontsize=22, ncol=4, loc='upper center')

# save figure and display
plt.savefig(out_path)
plt.show()

##################################################################################
# end
