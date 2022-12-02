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
from py_plt_utilities import PROJ_ROOT

##################################################################################
# SET GLOBAL PARAMETERS
##################################################################################
# define control flow to analyze 
CTR_FLW = 'deterministic_forecast'

# start date time of WRF forecast in YYYYMMDDHH
START_DT = '2019021200'

# analysis date time of inputs / outputs 
ANL_DT = '2019-02-14_00:00:00'

# pressure level for plotting wind barbs
W_PL = 850

##################################################################################
# Begin plotting
##################################################################################
# define derived data paths 
data_root = PROJ_ROOT + '/data/analysis/' + CTR_FLW
in_path = data_root + '/processed_numpy/' + START_DT
out_path = data_root + '/iwv_plots'
os.system('mkdir -p ' + out_path)

# load data
f = open(in_path + '/' + '/start_' + START_DT + '_forecast_' +\
         ANL_DT + '.bin', 'rb')
data = pickle.load(f)
f.close()

# load the projection
cart_proj = data['cart_proj']

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the GeoAxes to the projection used by WRF
ax0 = fig.add_axes([.86, .10, .05, .8])
ax1 = fig.add_axes([.05, .10, .8, .8], projection=cart_proj)
ax2 = fig.add_axes(ax1.get_position(), frameon=False)
ax3 = fig.add_axes([.03, .05, .8, .05], frameon=False)

# hard code the iwv scale to target ARs
iwv_min = 20
iwv_max = 60
color_map = sns.hls_palette(n_colors=40, h=0.68, s=0.9, l=0.55,
        as_cmap=True).reversed()
cnorm = nrm(vmin=iwv_min, vmax=iwv_max)

# make the scales of d01 / d02 equivalent in color map
iwv_d01 = data['d01']['iwv'].flatten()
iwv_d02 = data['d02']['iwv'].flatten()
iwvs = [iwv_d01, iwv_d02]

# find the index of values that lie below the iwv_min
indxs = [[], []]
for i in range(2):
    for k in range(len(iwvs[i])):
        if iwvs[i][k] < iwv_min:
            indxs[i].append(k)

# NaN out all values of d01 that lie in d02
iwv_d01[data['d02']['indx']] = np.nan

# NaN out all values of both domains that lie below the threshold
iwv_d01[indxs[0]] = np.nan
iwv_d02[indxs[1]] = np.nan

# plot iwv as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data['d01']['lons'], y=data['d01']['lats'],
            c=iwv_d01,
            alpha=0.600,
            cmap=color_map,
            norm=cnorm,
            marker='.',
            s=9,
            edgecolor='none',
            transform=crs.PlateCarree(),
           )

# plot iwv as intensity in scatter / heat plot for nested domain
ax1.scatter(x=data['d02']['lons'], y=data['d02']['lats'],
            c=iwv_d02,
            alpha=0.600,
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

# add slp contour plot
c_pl = ''
c_var = 'slp'
c_var_pl = np.array(data['d01'][c_var]).flatten()
c_var_levels =[1000, 1008, 1016, 1024]

# shape contour data for contour function in x / y coordinates
lats = np.array(data['d01']['lats'])
lons = np.array(data['d01']['lons'])
c_indx = np.shape(np.array(lons))
c_var_pl = np.reshape(c_var_pl, c_indx)
xx = np.reshape(data['d01']['xx'], c_indx)
yy = np.reshape(data['d01']['yy'], c_indx)

# keep min / max values for plot boundaries
x_min = np.min(xx)
x_max = np.max(xx)
y_min = np.min(yy)
y_max = np.max(yy)

# make contour plot with inline labels
CS = ax2.contour(
                 xx,
                 yy,
                 c_var_pl,
                 colors='black',
                 linestyles='dashdot',
                 levels=c_var_levels,
                )

ax2.clabel(CS, CS.levels, inline=True, fontsize=20)

# add geog / cultural features
ax1.add_feature(cfeature.COASTLINE)
ax1.add_feature(cfeature.STATES)
ax1.add_feature(cfeature.BORDERS)

# Add wind barbs plotting every w_kth data point, starting from w_k/2
w_k = 5000
lats = np.array(data['d01']['lats'])
lons = np.array(data['d01']['lons'])
wndx = data['d01']['xx']
wndy = data['d01']['yy']
wndu = data['d01']['pl_' + str(W_PL)]['u'].flatten()
wndv = data['d01']['pl_' + str(W_PL)]['v'].flatten()

# delete the wind barbs that fall below the threshold
wndx = np.delete(wndx, indxs[0])
wndy = np.delete(wndy, indxs[0])
wndu = np.delete(wndu, indxs[0])
wndv = np.delete(wndv, indxs[0])

barb_incs = {
             'half':5,
             'full':10,
             'flag':50,
            }

ax2.barbs(
          wndx[int(w_k/2)::w_k], wndy[int(w_k/2)::w_k],
          wndu[int(w_k/2)::w_k], wndv[int(w_k/2)::w_k],
          #transform=crs.PlateCarree(), 
          length=7,
          barb_increments=barb_incs,
         )

# create barb legend
ax3.barbs(
        [0, 0.5, 1],
        [0, 0, 0],
        [5, 10, 50],
        [0, 0, 0],
        length=10,
        barb_increments=barb_incs,
        )

ax3.set_xlim([-0.15, 1.2])
ax3.set_ylim([0.0, 0.05])
ax3.tick_params(
        bottom=False,
        labelbottom=False,
        left=False,
        labelleft=False,
        right=False,
        labelright=False,
        top=False,
        labeltop=False,
        )

ax2.tick_params(
        bottom=False,
        labelbottom=False,
        left=False,
        labelleft=False,
        right=False,
        labelright=False,
        top=False,
        labeltop=False,
        )

ax3.text(0.02, 0, '5 knots',  {'fontsize': 18})
ax3.text(0.52, 0, '10 knots', {'fontsize': 18})
ax3.text(1.02, 0, '50 knots', {'fontsize': 18})

# Add a color bar
cb(ax=ax0, cmap=color_map, norm=cnorm)
ax0.tick_params(
    labelsize=21,
    )

# Set the map bounds
ax1.set_xlim(data['d01']['x_lim'])
ax1.set_ylim(data['d01']['y_lim'])
ax2.set_xlim([x_min, x_max])
ax2.set_ylim([y_min, y_max])
ax2.set_position(ax1.get_position())

# Add the gridlines
ax1.gridlines(color='black', linestyle='dotted')

title1 = ANL_DT[:13] + r' - IWV $kg $ $m^{-2}$ / ' + str(W_PL) + 'hPa wind / ' +\
        c_pl + ' ' + c_var + ' contours'
start_dt = START_DT[:4] + '-' + START_DT[4:6] + '-' + START_DT[6:8] + '_' +\
        START_DT[8:]
title2 = 'fzh - ' + start_dt
plt.figtext(.50, .96, title1, horizontalalignment='center',
        verticalalignment='center', fontsize=22)
plt.figtext(.50, .91, title2, horizontalalignment='center',
        verticalalignment='center', fontsize=22)

fig.savefig(out_path + '/' + ANL_DT[:13] + '_fzh_' + start_dt + '_iwv_' +\
            str(W_PL) + '_wind_' + c_var + '.png')
plt.show()

##################################################################################
# end
