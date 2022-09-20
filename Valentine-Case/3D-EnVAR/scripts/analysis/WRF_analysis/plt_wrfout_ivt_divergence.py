##################################################################################
# Description
##################################################################################
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
# imports / exports
import matplotlib as mpl
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
import copy

##################################################################################
# file paths
start_date_1 = '2019021100' 
start_date_2 = '2019021400' 
f_in_path_1 = './processed_numpy/' + start_date_1
f_in_path_2 = './processed_numpy/' + start_date_2
f_out_path = './processed_numpy/ivt_diff_plots'
os.system('mkdir -p ' + f_out_path)

# date for files
date = '2019-02-14_00:00:00'

# load data file 1 which is used as the reference data
f_1 = open(f_in_path_1 + '/start_' + start_date_1 + '_forecast_' + date + '.txt', 'rb')
data = pickle.load(f_1)
f_1.close()

# load data file 2 which we compute divergence with
f_2 = open(f_in_path_2 + '/start_' + start_date_2 + '_forecast_' + date + '.txt', 'rb')
data_diff = pickle.load(f_2)
f_2.close()

# load the projection
cart_proj = data['cart_proj']

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the GeoAxes to the projection used by WRF
ax0 = fig.add_axes([.875, .10, .05, .8])
ax1 = fig.add_axes([.05, .10, .8, .8], projection=cart_proj)

# unpack variables and compute the divergence from f_2
h1_var_d01 = data['d01']['ivtm'].flatten()
h1_var_d02 = data['d02']['ivtm'].flatten()

h2_var_d01 = data_diff['d01']['ivtm'].flatten()
h2_var_d02 = data_diff['d02']['ivtm'].flatten()

h_diff_d01 = h1_var_d01 - h2_var_d01
h_diff_d02 = h1_var_d02 - h2_var_d02

# optional method for asymetric divergence plots
class MidpointNormalize(mpl.colors.Normalize):
    def __init__(self, vmin, vmax, midpoint=0, clip=False):
        self.midpoint = midpoint
        mpl.colors.Normalize.__init__(self, vmin, vmax, clip)

    def __call__(self, value, clip=None):
        normalized_min = max(0, 1 / 2 * (1 - abs((self.midpoint - self.vmin) / (self.midpoint - self.vmax))))
        normalized_max = min(1, 1 / 2 * (1 + abs((self.vmax - self.midpoint) / (self.midpoint - self.vmin))))
        normalized_mid = 0.5
        x, y = [self.vmin, self.midpoint, self.vmax], [normalized_min, normalized_mid, normalized_max]
        return np.ma.masked_array(np.interp(value, x, y))

# hard code the scale for intercomparability
abs_scale = 400

## make the scales of d01 / d02 equivalent in color map
#scale = np.append(h_diff_d01.data, h_diff_d02.data)
#scale = scale[~np.isnan(scale.data)]
#
## find the max / min value over the inner 100 - alpha percentile range of the data
#alpha = 1
#max_scale, min_scale = np.percentile(scale, [100 - alpha / 2, alpha / 2])
#
## find the largest magnitude divergence of the above data
#abs_scale = np.max([abs(max_scale), abs(min_scale)])

# make a symmetric color map about zero
cnorm = nrm(vmin=-abs_scale, vmax=abs_scale)
color_map = sns.diverging_palette(280, 30, l=65, as_cmap=True)

# NaN out all values of d01 that lie in d02
h_diff_d01[data['d02']['indx']] = np.nan

# plot ivtm as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data['d01']['lons'], y=data['d01']['lats'],
            c=h_diff_d01.data,
            cmap=color_map,
            norm=cnorm,
            marker='.',
            s=9,
            edgecolor='none',
            transform=crs.PlateCarree(),
           )

# plot ivtm as intensity in scatter / heat plot for nested domain
ax1.scatter(x=data['d02']['lons'], y=data['d02']['lats'],
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
         [data['d02']['x_lim'][0], data['d02']['x_lim'][1]],
         [data['d02']['y_lim'][0], data['d02']['y_lim'][0]],
         linestyle='-',
         linewidth=1.5,
         color='k',
        )

# top boundary
ax1.plot(
         [data['d02']['x_lim'][0], data['d02']['x_lim'][1]],
         [data['d02']['y_lim'][1], data['d02']['y_lim'][1]],
         linestyle='-',
         linewidth=1.5,
         color='k',
        )

# left boundary
ax1.plot(
         [data['d02']['x_lim'][0], data['d02']['x_lim'][0]],
         [data['d02']['y_lim'][0], data['d02']['y_lim'][1]],
         linestyle='-',
         linewidth=1.5,
         color='k',
        )

# right boundary
ax1.plot(
         [data['d02']['x_lim'][1], data['d02']['x_lim'][1]],
         [data['d02']['y_lim'][0], data['d02']['y_lim'][1]],
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
    labelsize=16,
    )

# Set the map bounds
ax1.set_xlim(data['d01']['x_lim'])
ax1.set_ylim(data['d01']['y_lim'])

# Add the gridlines
ax1.gridlines(color='black', linestyle='dotted')

# make title and save figure
d1 = copy.copy(start_date_1) 
d2 = copy.copy(start_date_2)

d1 = d1[:4] + ':' + d1[4:6] + ':' + d1[6:8] + '_' + d1[8:] + ':00:00'
d2 = d2[:4] + ':' + d2[4:6] + ':' + d2[6:8] + '_' + d2[8:] + ':00:00'

title1 = 'ivtm - ' + date
title2 = 'fzh ' + d1 + ' minus fzh ' + d2
plt.figtext(.50, .96, title1, horizontalalignment='center', verticalalignment='center', fontsize=18)
plt.figtext(.50, .91, title2, horizontalalignment='center', verticalalignment='center', fontsize=18)
plt.savefig(f_out_path + '/' + date + '_ivtm_diff_plot_fzh1_' + d1 + '_fzh2_' + d2 + '.png')
plt.show()
