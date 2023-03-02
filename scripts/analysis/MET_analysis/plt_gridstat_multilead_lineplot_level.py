##################################################################################
# Description
##################################################################################
# This script is designed to generate line plots in Matplotlib from MET grid_stat
# output files, preprocessed with the companion script proc_24hr_QPF.py.  This
# plotting scheme is designed to plot thresholded data as lines in the vertical
# axis and the number of lead hours to the valid time for verification from the
# forecast initialization in the horizontal axis. The global parameters for the
# script below control the initial times for the forecast initializations, as
# well as the valid date of the verification. Stats to compare can be reset in
# the global parameters with heat map color bar changing scale dynamically. Here
# the threshold level to be plotted must be specified.
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
            'WWRF'
            #'GFS',
            #'ECMWF',
           ]

# define optional list of stats files prefixes
PRFXS = [
        'SQUARE_BILIN_3',
        'SQUARE_DW_MEAN_3',
        'SQUARE_BUDGET_3',
        'SQUARE_NEAREST_1',
        ]

# define case-wise sub-directory
CSE = 'VD'

# verification domain for the forecast data
GRD='d02'

# verification domain for the calibration data
REF='0.25'

# threshold level to plot
#LEV = '>0.0'
#LEV = '>=10.0'
LEV = '>=25.4'
#LEV = '>=50.8'
#LEV = '>=101.6'

# starting date and zero hour of forecast cycles
START_DT = '2019-02-08T00:00:00'

# final date and zero hour of data of forecast cycles
END_DT = '2019-02-14T00:00:00'

# valid date for the verification
VALID_DT = '2019-02-15T00:00:00'

# number of hours between zero hours for forecast data
CYCLE_INT = 24

# MET stat file type -- should be leveled data
#TYPE = 'cts'
#TYPE = 'nbrcts'
TYPE = 'nbrcnt'

# MET stat column names to be made to leveled line data
#STATS = ['HK', 'GSS']
#STATS = ['PODY', 'POFD']
#STATS = ['CSI', 'FAR']
#STATS = ['CSI', 'FBIAS']
#STATS = ['FAR', 'POFD']
STATS = ['FSS', 'AFSS']

# landmask for verification region -- need to be set in earlier preprocessing
LND_MSK = 'CA_Climate_Zone_16_Sierra'
#LND_MSK = 'CALatLonPoints'
#LND_MSK = 'FULL'

##################################################################################
# Begin plotting
##################################################################################
# create a figure
fig = plt.figure(figsize=(11.25,8.63))
num_flws = len(CTR_FLWS)
num_pfxs = len(PRFXS)

# set colors and storage for looping
line_colors = sns.color_palette("husl", num_flws * num_pfxs)

# Set the axes
ax0 = fig.add_axes([.110, .43, .85, .33])
ax1 = fig.add_axes([.110, .10, .85, .33])

line_list = []
line_labs = []

# create date time object from string
valid_dt = dt.fromisoformat(VALID_DT)

for i in range(num_flws):
    # loop on control flows
    ctr_flw = CTR_FLWS[i]
    param = ctr_flw.split('_')[-1]

    for m in range(num_pfxs):
        # loop on prefixes
        pfx = PRFXS[m]
        line_lab = param + '_' + pfx
        line_labs.append(line_lab)

        # define derived data paths 
        cse = CSE + '/' + ctr_flw
        data_root = USR_HME + '/data/analysis/' + cse + '/MET_analysis'
        stat0 = STATS[0]
        stat1 = STATS[1]
        
        # define the input name
        if ctr_flw == 'ECMWF' or ctr_flw == 'GFS':
            in_path = data_root + '/grid_stats_' + pfx + '_' + REF + '_' + START_DT +\
                      '_to_' + END_DT + '.bin'
    
        else:
            in_path = data_root + '/grid_stats_' + pfx + '_' + GRD + '_' + START_DT +\
                      '_to_' + END_DT + '.bin'
        
        f = open(in_path, 'rb')
        data = pickle.load(f)
        f.close()
        
        # load the values to be plotted along with landmask, lead and threshold
        vals = [
                'VX_MASK',
                'FCST_LEAD',
                'FCST_THRESH',
                'FCST_VALID_END',
               ]
        vals += STATS
    
        # infer existence of confidence intervals with precedence for bootstrap
        cnf_lvs = []
        for k in range(2):
            stat = STATS[k]
            if stat + '_BCL' in data[TYPE] and\
                not (data[TYPE][stat + '_BCL'].isnull().values.any()):
                    vals.append(stat + '_BCL')
                    vals.append(stat + '_BCU')
                    cnf_lvs.append('_BC')
    
            elif stat + '_NCL' in data[TYPE] and\
                not (data[TYPE][stat + '_NCL'].isnull().values.any()):
                    vals.append(stat + '_NCL')
                    vals.append(stat + '_NCU')
                    cnf_lvs.append('_NC')
    
            else:
                cnf_lvs.append(False)
    
        # cut down df to specified valid date / region and obtain leads of data 
        stat_data = data[TYPE][vals]
        stat_data = stat_data.loc[(stat_data['VX_MASK'] == LND_MSK)]
        stat_data = stat_data.loc[(stat_data['FCST_THRESH'] == LEV)]
        stat_data = stat_data.loc[(stat_data['FCST_VALID_END'] ==
                                   valid_dt.strftime('%Y%m%d_%H%M%S'))]
        data_leads = sorted(list(set(stat_data['FCST_LEAD'].values)),
                            key=lambda x:(len(x), x))
        num_leads = len(data_leads)
        
        # create array storage for stats and plot
        for k in range(2):
            exec('ax = ax%s'%k)
            if cnf_lvs[k]:
                tmp = np.zeros([num_leads, 3])
        
                for j in range(num_leads):
                    val = stat_data.loc[(stat_data['FCST_LEAD'] == data_leads[j])]
                    tmp[j, 0] = val[STATS[k]]
                    tmp[j, 1] = val[STATS[k] + cnf_lvs[k] + 'L']
                    tmp[j, 2] = val[STATS[k] + cnf_lvs[k] + 'U']
                
                ax.fill_between(range(num_leads), tmp[:, 1], tmp[:, 2], alpha=0.5,
                        color=line_colors[i * num_pfxs + m])
                l, = ax.plot(range(num_leads), tmp[:, 0], linewidth=2,
                        marker=(3 + i * num_pfxs + m, 0, 0) , markersize=18, color=line_colors[i * num_pfxs + m])
    
            else:
                tmp = np.zeros([num_leads])
            
                for j in range(num_leads):
                    val = stat_data.loc[(stat_data['FCST_LEAD'] == data_leads[j])]
                    tmp[j] = val[STATS[k]]
                
                l, = ax.plot(range(num_leads), tmp[:], linewidth=2,
                        marker=(3 + i * num_pfxs + m, 0, 0) , markersize=18, color=line_colors[i * num_pfxs + m])
    
                ax.plot(range(num_leads), tmp[:], linewidth=2,
                        marker=(3 + i * num_pfxs + m, 0, 0) , markersize=18, color=line_colors[i * num_pfxs + m])
            
            
        # add the line type to the legend
        line_list.append(l)

##################################################################################
# define display parameters

# generate tic labels based on hour values
for i in range(num_leads):
    data_leads[i] = data_leads[i][:-4]

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
title2='Verification region -- ' + LND_MSK + ' Threshold ' + LEV + ' mm'
lab0=STATS[0]
lab1=STATS[1]
lab2='Forecast lead hrs'
plt.figtext(.5, .98, title1, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.5, .93, title2, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

plt.figtext(.05, .595, lab0, horizontalalignment='right', rotation=90,
            verticalalignment='center', fontsize=22)

plt.figtext(.04, .265, lab1, horizontalalignment='right', rotation=90,
            verticalalignment='center', fontsize=22)

plt.figtext(.5, .02, lab2, horizontalalignment='center',
            verticalalignment='center', fontsize=22)

fig.legend(line_list, line_labs, fontsize=18, ncol=min(num_flws * num_pfxs, 2),
           loc='center', bbox_to_anchor=[0.5, 0.83])

# save figure and display
out_path = USR_HME + '/data/analysis/' + CSE + '/' + VALID_DT + '_' +\
           LND_MSK + '_' + stat0 + '_' +\
           stat1 + '_lev_' + LEV + '_lineplot.png'
    
plt.savefig(out_path)
plt.show()

##################################################################################
# end
