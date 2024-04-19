##################################################################################
# Description
##################################################################################
# This plots the point-wise difference in IWV from two wrfout files
# pre-processed with the companion proc_wrfout_np.py script.  Start dates
# and valide date of the output file are specified in the global parameters
# below, where this can be used to measure versus ERA5 downscaled to the 
# forecast domain.
#
##################################################################################
# License Statement:
##################################################################################
# This software is Copyright © 2024 The Regents of the University of California.
# All Rights Reserved. Permission to copy, modify, and distribute this software
# and its documentation for educational, research and non-profit purposes,
# without fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three paragraphs
# appear in all copies. Permission to make commercial use of this software may
# be obtained by contacting:
#
#     Office of Innovation and Commercialization
#     9500 Gilman Drive, Mail Code 0910
#     University of California
#     La Jolla, CA 92093-0910
#     innovation@ucsd.edu
#
# This software program and documentation are copyrighted by The Regents of the
# University of California. The software program and documentation are supplied
# "as is", without any accompanying services from The Regents. The Regents does
# not warrant that the operation of the program will be uninterrupted or
# error-free. The end-user understands that the program was developed for
# research purposes and is advised not to rely exclusively on the program for
# any reason.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE. THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED
# HEREUNDER IS ON AN “AS IS” BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO
# OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
# 
##################################################################################
# Imports
##################################################################################
import matplotlib
# use this setting on COMET / Skyriver for x forwarding
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize as nrm
from matplotlib.cm import get_cmap
from matplotlib.colorbar import Colorbar as cb
import seaborn as sns
import cartopy.crs as crs
import cartopy.feature as cfeature
import numpy as np
import pickle
import os
from datetime import datetime as dt
from datetime import timedelta
from py_plt_utilities import USR_HME

##################################################################################
# SET GLOBAL PARAMETERS
##################################################################################
# define control flows to analyze, first is control second is treatment 
CTR_ROOT = 'deterministic_forecast'
CTR_FLW1 = CTR_ROOT + '_control'
CTR_FLW2 = CTR_ROOT + '_treatment'

#CTR_FLW1 = CTR_ROOT + '_control'
#CTR_FLW2 = CTR_ROOT + '_control'
#
#CTR_FLW1 = CTR_ROOT + '_treatment'
#CTR_FLW2 = CTR_ROOT + '_treatment'

# start date time of WRF forecasts 1 and 2
START_DT1 = '2021-01-23_00:00:00' 
START_DT2 = '2021-01-23_00:00:00' 

# valid date time for analysis
ANL_DT = '2021-01-28_00:00:00'

# max domain to plot
MAX_DOM = 1

##################################################################################
# Begin plotting
##################################################################################
# define derived data paths 
data_root = USR_HME + '/data/analysis'
in_path1 = data_root + '/processed_numpy/' + START_DT1
in_path2 = data_root + '/processed_numpy/' + START_DT2
out_path = data_root + '/iwv_diff_plots'
os.system('mkdir -p ' + out_path)

# convert from iso times
anl_dt = dt.fromisoformat(ANL_DT)
start_dt1 = dt.fromisoformat(START_DT1)
in_path1 = data_root + '/' + CTR_FLW1 + '/' + 'WRF_analysis' +\
        '/' + start_dt1.strftime('%Y%m%d%H')

start_dt2 = dt.fromisoformat(START_DT2)
in_path2 = data_root + '/' + CTR_FLW2 + '/' + 'WRF_analysis' +\
        '/' + start_dt2.strftime('%Y%m%d%H')

out_path = data_root + '/iwv_diff_plots/' + CTR_FLW2 + '_diff_' + CTR_FLW1
os.system('mkdir -p ' + out_path)

# load control data file 1 which we subtract from treatment data
f1 = open(in_path1 + '/start_' + START_DT1 + '_forecast_' +\
        ANL_DT + '.bin', 'rb')
dataf1 = pickle.load(f1)
f1.close()

# load data file 2 which is used as the treatment data
f2 = open(in_path2 + '/start_' + START_DT2 + '_forecast_' +\
        ANL_DT + '.bin', 'rb')
dataf2 = pickle.load(f2)
f2.close()

# load the projection
cart_proj = dataf1['cart_proj']

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the GeoAxes to the projection used by WRF
ax0 = fig.add_axes([.86, .07, .05, .8])
ax1 = fig.add_axes([.05, .07, .8, .8], projection=cart_proj)

# unpack variables and compute the divergence from f2
f1_d01 = dataf1['d01']['iwv'].flatten()
f2_d01 = dataf2['d01']['iwv'].flatten()
h_diff_d01 = f2_d01 - f1_d01

if MAX_DOM == 2:
    f1_d02 = dataf1['d02']['iwv'].flatten()
    f2_d02 = dataf2['d02']['iwv'].flatten()
    h_diff_d02 = f2_d02 - f1_d02

# optional method for asymetric divergence plots
class MidpointNormalize(nrm):
    def __init__(self, vmin, vmax, midpoint=0, clip=False):
        self.midpoint = midpoint
        nrm.__init__(self, vmin, vmax, clip)

    def __call__(self, value, clip=None):
        normalized_min = max(0, 1 / 2 * (1 - abs((self.midpoint - self.vmin) / (self.midpoint - self.vmax))))
        normalized_max = min(1, 1 / 2 * (1 + abs((self.vmax - self.midpoint) / (self.midpoint - self.vmin))))
        normalized_mid = 0.5
        x, y = [self.vmin, self.midpoint, self.vmax], [normalized_min, normalized_mid, normalized_max]
        return np.ma.masked_array(np.interp(value, x, y))

# hard code the scale for intercomparability
#abs_scale = 40

# make the scales of d01 / d02 equivalent in color map
scale = np.array([])
scale = np.append(scale, h_diff_d01.data)
if MAX_DOM == 2:
    scale = np.append(scale, h_diff_d02.data)

scale = scale[~np.isnan(scale.data)]

# find the max / min value over the inner 100 - alpha percentile range of the data
alpha = 1
max_scale, min_scale = np.percentile(scale, [100 - alpha / 2, alpha / 2])

# find the largest magnitude divergence of the above data
abs_scale = np.max([abs(max_scale), abs(min_scale)])

if MAX_DOM == 2:
    # NaN out all values of d01 that lie in d02
    h_diff_d01[dataf1['d02']['indx']] = np.nan

# make a symmetric color map about zero
cnorm = nrm(vmin=-abs_scale, vmax=abs_scale)
color_map = sns.diverging_palette(280, 30, l=65, as_cmap=True)

if MAX_DOM == 2:
    # NaN out all values of d01 that lie in d02
    h_diff_d01[dataf1['d02']['indx']] = np.nan

# plot iwv as intensity in scatter / heat plot for parent domain
ax1.scatter(x=dataf1['d01']['lons'], y=dataf1['d01']['lats'],
            c=h_diff_d01.data,
            cmap=color_map,
            norm=cnorm,
            marker='.',
            s=16,
            edgecolor='none',
            transform=crs.PlateCarree(),
           )

if MAX_DOM == 2:
    # plot iwv as intensity in scatter / heat plot for nested domain
    ax1.scatter(x=dataf1['d02']['lons'], y=dataf1['d02']['lats'],
                c=h_diff_d02.data,
                cmap=color_map,
                norm=cnorm,
                marker='.',
                s=1,
                edgecolor='none',
                transform=crs.PlateCarree(),
               )
    
    # bottom boundary
    ax1.plot(
             [dataf1['d02']['x_lim'][0], dataf1['d02']['x_lim'][1]],
             [dataf1['d02']['y_lim'][0], dataf1['d02']['y_lim'][0]],
             linestyle='-',
             linewidth=1.5,
             color='k',
            )
    
    # top boundary
    ax1.plot(
             [dataf1['d02']['x_lim'][0], dataf1['d02']['x_lim'][1]],
             [dataf1['d02']['y_lim'][1], dataf1['d02']['y_lim'][1]],
             linestyle='-',
             linewidth=1.5,
             color='k',
            )
    
    # left boundary
    ax1.plot(
             [dataf1['d02']['x_lim'][0], dataf1['d02']['x_lim'][0]],
             [dataf1['d02']['y_lim'][0], dataf1['d02']['y_lim'][1]],
             linestyle='-',
             linewidth=1.5,
             color='k',
            )
    
    # right boundary
    ax1.plot(
             [dataf1['d02']['x_lim'][1], dataf1['d02']['x_lim'][1]],
             [dataf1['d02']['y_lim'][0], dataf1['d02']['y_lim'][1]],
             linestyle='-',
             linewidth=1.5,
             color='k',
            )

# add geog / cultural features
ax1.add_feature(cfeature.COASTLINE)
ax1.add_feature(cfeature.STATES)
ax1.add_feature(cfeature.BORDERS)

# Add a color bar
cb(ax=ax0, cmap=color_map, norm=cnorm)
ax1.tick_params(
    labelsize=21,
    )

# Set the map bounds
ax1.set_xlim(dataf1['d01']['x_lim'])
ax1.set_ylim(dataf1['d01']['y_lim'])

# Add the gridlines
ax1.gridlines(color='black', linestyle='dotted')

# make title and save figure
d1 = start_dt1.strftime('%Y-%m-%dT%H') 
d2 = start_dt2.strftime('%Y-%m-%dT%H') 

ctr_flw1 = CTR_FLW1.split('_')
ctr_flw2 = CTR_FLW2.split('_')

out_name = out_path + '/' +  anl_dt.strftime('%Y-%m-%dT%H') +\
        '_iwv_' +\
        d2 + '_' + CTR_FLW2 +\
        '_minus_' +\
        d1 + '_' + CTR_FLW1 +\
        '.png' 

title1 = 'iwv - valid date ' + anl_dt.strftime('%Y-%m-%dT%H') 
title2 = ''
for i in range(len(ctr_flw2)):
    title2 += ctr_flw2[i] + ' '
title2 = title2 + ' fzh - ' + d2
title3 ='minus'
title4 = ''
for i in range(len(ctr_flw1)):
    title4 += ctr_flw1[i] + ' '
title4 = title4 + ' fzh - ' + d1

plt.figtext(.50, .03, title1, horizontalalignment='center', verticalalignment='center', fontsize=22)
plt.figtext(.50, .98, title2, horizontalalignment='center', verticalalignment='center', fontsize=20)
plt.figtext(.50, .94, title3, horizontalalignment='center', verticalalignment='center', fontsize=20)
plt.figtext(.50, .90, title4, horizontalalignment='center', verticalalignment='center', fontsize=20)
plt.savefig(out_name)
plt.show()

##################################################################################
# end
