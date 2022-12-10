##################################################################################
# Description
##################################################################################
# This will plot IWV, wind and pressure contour data generated from the companion
# script proc_wrfout_np.py.  The plotting script will null out values of the
# parent domain lying in nested domains, currently only developed for two
# domains.  
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
from py_plt_utilities import PROJ_ROOT

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
# Begin plotting
##################################################################################
# define derived data paths 
data_root = PROJ_ROOT + '/data/analysis/' + CTR_FLW + '/MET_analysis'

# convert to date times
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)
valid_date = dt.fromisoformat(VALID_DATE)

# define the output name
in_path = data_root + '/grid_stats_lead_' + START_DATE +\
          '_to_' + END_DATE + '_valid_' + VALID_DATE +\
          '.bin'

f = open(in_path, 'rb')
data = pickle.load(f)
f.close()

vals = [
        'VX_MASK',
        'FCST_LEAD',
        'FCST_THRESH',
        'PODY',
        'PODY_NCL',
        'PODY_NCU',
        'PODN',
        'PODN_NCL',
        'PODN_NCU'
       ]

level_data = data['cts'][vals]

# cut down df to CA region and obtain levels of data 
level_data = level_data.loc[(level_data['VX_MASK'] == 'CALatLonPoints')]
data_levels =  sorted(list(set(level_data['FCST_THRESH'].values)))
data_leads = sorted(list(set(level_data['FCST_LEAD'].values)))[::-1]
num_levels = len(data_levels)
num_leads = len(data_leads)
stats = ['PODY', 'PODN']

# create array storage for probs
tmp = np.zeros([num_levels, num_leads, 2])

for k in range(2):
    for i in range(num_levels):
        for j in range(num_leads):
            val = level_data.loc[(level_data['FCST_THRESH'] == data_levels[i]) &
                                 (level_data['FCST_LEAD'] == data_leads[j])]
            
            tmp[i, j, k] = val[stats[k]]

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the GeoAxes to the projection used by WRF
ax0 = fig.add_axes([.89, .10, .05, .8])
ax1 = fig.add_axes([.08, .10, .39, .8])
ax2 = fig.add_axes([.49, .10, .39, .8])

max_scale = 1.0
min_scale = 0.0
color_map = sns.cubehelix_palette(20, start=.75, rot=1.50, as_cmap=True, reverse=True, dark=0.25)
sns.heatmap(tmp[:,:,0], linewidth=0.5, ax=ax1, cbar_ax=ax0, vmin=min_scale, vmax=max_scale, cmap=color_map)
sns.heatmap(tmp[:,:,1], linewidth=0.5, ax=ax2, cbar_ax=ax0, vmin=min_scale, vmax=max_scale, cmap=color_map)


for i in range(num_leads):
    data_leads[i] = data_leads[i][:2]

ax1.set_xticklabels(data_leads)
ax1.set_yticklabels(data_levels)
ax2.set_xticklabels(data_leads)
ax2.set_yticklabels(data_levels)


ax0.tick_params(
        labelsize=20
        )

ax1.tick_params(
        labelsize=20
        )

ax2.tick_params(
        labelsize=20,
        left=False,
        labelleft=False,
        right=False,
        labelright=False,
        )

title1='24hr accumulated precip at ' + VALID_DATE
lab1='Forecast lead hrs'
lab2='Precip Thresh mm'
lab3='PODY'
lab4='PODN'
plt.figtext(.5, .02, lab1, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.02, .5, lab2, horizontalalignment='center',
            verticalalignment='center', fontsize=22, rotation='90')

plt.figtext(.5, .98, title1, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.2745, .92, lab3, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.6845, .92, lab4, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.show()
