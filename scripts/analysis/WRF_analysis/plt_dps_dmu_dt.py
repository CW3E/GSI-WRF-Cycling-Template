##################################################################################
# Description
##################################################################################
# This script plots the time series of dpsdt, dmudt and maxdmu taken from lines
#
#     d0X   Domain average of dpsdt, dmudt (mb/3h): xtime dpsdt dmudt 
#     d0X   Max mu change time step: xgrid ygrid maxdmu 
#
# in a generic rsl.*.* file from a WRF run.  The file should be preprocessed into
# a Pandas dataframe with the companion  `proces_dps_dmu_dt.py` script, where this
# plotting script should point to the output of the preprocessing script for the
# input file.
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
# Data input and plot output directories should be defined in the below along
# with MAX_DOM to control the number of domains processed.  Testing on more
# than two domains is still pending.
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
import datetime as dt
import matplotlib
# use this setting on COMET / Skyriver for x forwarding
matplotlib.use('TkAgg')
from matplotlib import pyplot as plt
from py_plt_utilities import USR_HME

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flow to analyze 
CTR_FLW = '3dvar_control'

# starting date and zero hour of data
START_DATE = '2021-01-21T18:00:00'

# final date and zero hour of data
END_DATE = '2021-01-28T18:00:00'

# define domain to plot
DOM = 1

##################################################################################
# Begin plotting
##################################################################################
# define derived data paths 
data_root = USR_HME + '/data/analysis/' + CTR_FLW + '/WRF_analysis'
in_path = data_root + '/' + CTR_FLW + '_WRF_dps_dmu_dt_' + START_DATE + '_to_' +\
          END_DATE + '.bin'
out_path = data_root + '/' + CTR_FLW + '_WRF_spin_up_' + START_DATE + '_to_' +\
          END_DATE + '.png'

# load and plot data
f = open(in_path, 'rb')
tmp = pickle.load(f)
f.close()

# load dataframe
exec('data = tmp[\'d0%s\']'%DOM)

# define three panel figure with pre-defined size
fig = plt.figure(figsize=(16,8))
ax1 = fig.add_axes([.075, .52, .85, .38])
ax0 = fig.add_axes([.075, .14, .85, .38])

# set colors and storage for looping
line_colors = ['#d95f02', '#7570b3', '#1b9e77']

# generate lines, saving values for legend
l1, = ax1.plot(data['dpsdt'], linewidth=2, markersize=26, color=line_colors[0])
l0, = ax0.plot(data['dmudt'], linewidth=2, markersize=26, color=line_colors[1])

# set the legend values
line_list = [l1, l0]
line_labs = [r'$\frac{\mathrm{d}ps}{\mathrm{d}t}$hPa/3hr',
             r'$\frac{\mathrm{d}\mu}{\mathrm{d}t}$mb/3hr']

xtime = data['xtime'].values
dates = data['wrf_time'].values

tic_mark = []
tic_labs = []

steps = len(xtime)

for i in range(steps):
    x_0 = xtime[i-1]
    x_1 = xtime[i]

    if x_1 < x_0:
        tic_mark.append(i)
        date = str(dates[i]).split(':')[0]
        tic_labs.append(date)

##################################################################################
# define display parameters

# set plot range
ax1.set_xlim([-50, steps])
ax0.set_xlim([-50, steps])

# tick parameters
ax1.tick_params(
    labelsize=11,
    labelbottom=False,
    )

ax0.tick_params(
    labelsize=11,
    )

# add legend and tics
fig.legend(line_list, line_labs, fontsize=18, ncol=4, loc='upper center')
ax1.set_xticks(tic_mark)
ax0.set_xticks(tic_mark, labels=tic_labs, rotation=45, ha='right')

# save figure and display
plt.savefig(out_path)
plt.show()

##################################################################################
# end
