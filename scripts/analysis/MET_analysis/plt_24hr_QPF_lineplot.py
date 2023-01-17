##################################################################################
# Description
##################################################################################
# This script is designed to generate line plots in Matplotlib from MET grid_stat
# output files, preprocessed with the companion script proc_24hr_QPF.py.  This
# plotting scheme is designed to plot non-threshold data as lines in the vertical
# axis and the number of lead hours to the valid time for verification from the
# forecast initialization in the horizontal axis. The global parameters for the
# script below control the initial times for the forecast initializations, as
# well as the valid date of the verification. Stats to compare can be reset in
# the global parameters with heat map color bar changing scale dynamically.
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
import matplotlib
# use this setting on COMET / Skyriver for x forwarding
matplotlib.use('TkAgg')
from datetime import datetime as dt
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize as nrm
from matplotlib.cm import get_cmap
from matplotlib.colorbar import Colorbar as cb
import seaborn as sns
import numpy as np
import pickle
import os
from py_plt_utilities import USR_HME
import ipdb

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# define control flows to analyze 
CTR_FLWS = [
            'deterministic_forecast_b0.30',
            'deterministic_forecast_b0.50',
            'deterministic_forecast_b0.60',
            'deterministic_forecast_b0.70',
            'deterministic_forecast_b0.80',
            'deterministic_forecast_b0.90',
            'deterministic_forecast_b1.00',
           ]

# define case-wise sub-directory
CSE = 'VD'

# starting date and zero hour of forecast cycles
START_DT = '2019-02-11T00:00:00'

# final date and zero hour of data of forecast cycles
END_DT = '2019-02-14T00:00:00'

# valid date for the verification
VALID_DT = '2019-02-15T00:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 24

# MET stat column names to be made to heat plots / labels
#STATS = ['RMSE', 'PR_CORR']
STATS = ['MAD', 'SP_CORR']

# landmask for verification region -- need to be set in earlier preprocessing
LND_MSK = 'CALatLonPoints'
#LND_MSK = 'FULL'

##################################################################################
# Begin plotting
##################################################################################
# create a figure
fig = plt.figure(figsize=(11.25,8.63))

# set colors and storage for looping
line_colors = ['#1b9e77', '#d95f02', '#7570b3', '#e7298a','#66a61e','#e6ab02','#a6761d', 'k']
#line_colors = ['#1b9e77', '#7570b3', '#d95f02', 'k']

# Set the axes
ax1 = fig.add_axes([.110, .10, .85, .33])
ax0 = fig.add_axes([.110, .43, .85, .33])

num_flws = len(CTR_FLWS)
line_list = []
line_labs = []

for i in range(num_flws):
    # loop on control flows
    ctr_flw = CTR_FLWS[i]
    param = ctr_flw.split('_')[-1]
    line_labs.append(param)

    # define derived data paths 
    cse = CSE + '/' + ctr_flw
    data_root = USR_HME + '/data/analysis/' + cse + '/MET_analysis'
    stat1 = STATS[0]
    stat2 = STATS[1]
    
    # define the output name
    in_path = data_root + '/grid_stats_lead_' + START_DT +\
              '_to_' + END_DT + '_valid_' + VALID_DT +\
              '.bin'
    
    f = open(in_path, 'rb')
    data = pickle.load(f)
    f.close()
    
    # all values below are taken from the raw data frame, SOME may be set
    # in the above STATS as valid heat plot options
    vals = [
            'VX_MASK',
            'FCST_LEAD',
            'RMSE',
            'BCMSE',
            'MSE',
            'MAD',
            'PR_CORR',
            'SP_CORR',
           ]
    
    # cut down df to specified region and obtain leads of data 
    level_data = data['cnt'][vals]
    level_data = level_data.loc[(level_data['VX_MASK'] == LND_MSK)]
    data_leads = sorted(list(set(level_data['FCST_LEAD'].values)))[::-1]
    num_leads = len(data_leads)
    
    # create array storage for stats
    tmp = np.zeros([num_leads, 2])
    
    for k in range(2):
        for j in range(num_leads):
            val = level_data.loc[(level_data['FCST_LEAD'] == data_leads[j])]
            tmp[j, k] = val[STATS[k]]
    
    l, = ax1.plot(range(num_leads), tmp[:, 1], linewidth=2, markersize=26,
            color=line_colors[i])
    line_list.append(l)

    ax0.plot(range(num_leads), tmp[:, 0], linewidth=2, markersize=26,
            color=line_colors[i])

##################################################################################
# define display parameters

# generate tic labels based on hour values
for i in range(num_leads):
    data_leads[i] = data_leads[i][:2]

ax1.set_xticks(range(num_leads))
ax1.set_xticklabels(data_leads)

# tick parameters
ax1.tick_params(
        labelsize=18
        )

ax0.tick_params(
        labelsize=18
        )

ax0.tick_params(
        labelsize=18,
        bottom=False,
        labelbottom=False,
        right=False,
        labelright=False,
        )

title1='24hr accumulated precip at ' + VALID_DT
title2='Verification region -- ' + LND_MSK
lab1='Forecast lead hrs'
lab2=STATS[1]
lab3=STATS[0]
plt.figtext(.5, .02, lab1, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.5, .98, title1, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.5, .93, title2, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.05, .265, lab2, horizontalalignment='right', rotation=90,
            verticalalignment='center', fontsize=22)

plt.figtext(.05, .595, lab3, horizontalalignment='right', rotation=90,
            verticalalignment='center', fontsize=22)

fig.legend(line_list, line_labs, fontsize=22, ncol=num_flws, loc='center', bbox_to_anchor=[0.5, 0.83])

# save figure and display
out_path = USR_HME + '/data/analysis/' + CSE + '/' + VALID_DT + '_' +\
           LND_MSK + '_' + stat1 + '_' +\
           stat2 + '_lineplot.png'
    
plt.savefig(out_path)
plt.show()

##################################################################################
# end
