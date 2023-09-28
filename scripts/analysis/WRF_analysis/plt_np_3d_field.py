##################################################################################
# Description
##################################################################################
# This will plot an arbitrary 3D field interpolated to a specific pressure level
# data generated from the companion script proc_wrfout_np.py.  The plotting 
# script will null out values of the parent domain lying in nested domains,
# currently only developed for two domains.
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
# define control flow to analyze 
CTR_FLW = 'deterministic_forecast_treatment'

# start date time of WRF forecast in YYYYMMDDHH
START_DT = '2021-01-23_00:00:00'

# analysis date time of inputs / outputs 
ANL_DT = '2021-01-28_00:00:00'

# max domain to plot
MAX_DOM = 1

# heat plot pressure level and variable
H_PL = 500
H_VAR = 'rh'

# contour plot pressure level and variable, leave pressure level '' for sea level
C_PL = ''
C_VAR = 'slp'

# pressure level for plotting wind barbs
W_PL = 850

##################################################################################
# Begin plotting
##################################################################################
# convert from iso times
anl_dt = dt.fromisoformat(ANL_DT)
start_dt = dt.fromisoformat(START_DT)

# define derived data paths 
data_root = USR_HME + '/data/analysis/' + CTR_FLW + '/WRF_analysis'
in_path = data_root + '/' + start_dt.strftime('%Y%m%d%H')
out_path = data_root + '/3df_plots'
os.system('mkdir -p ' + out_path)

# load data
f = open(in_path + '/start_' + START_DT + '_forecast_' + ANL_DT + '.bin', 'rb')
data = pickle.load(f)
f.close()

# load the projection
cart_proj = data['cart_proj']

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the GeoAxes to the projection used by WRF
ax0 = fig.add_axes([.86, .08, .05, .8])
ax1 = fig.add_axes([.05, .08, .8, .8], projection=cart_proj)
ax2 = fig.add_axes(ax1.get_position(), frameon=False)
ax3 = fig.add_axes([.03, .03, .8, .05], frameon=False)

# extract pressure level data
H_VAR_d01 = data['d01']['pl_' + str(H_PL)][H_VAR].flatten()
if MAX_DOM == 2:
    H_VAR_d02 = data['d02']['pl_' + str(H_PL)][H_VAR].flatten()
    H_VARS = [H_VAR_d01, H_VAR_d02]
else:
    H_VARS = [H_VAR_d01]

# define color map and scale depending on variable
if H_VAR == 'rh':
   # % units with fixed range
   cnorm = nrm(vmin=0, vmax=100)
   color_map = sns.cubehelix_palette(80, start=.75, rot=1.50, as_cmap=True, reverse=True, dark=0.25)

elif H_VAR == 'temp':
    # normal temperature range will be hard coded
    cnorm = nrm(vmin=250, vmax=314)
    color_map = sns.color_palette('viridis', as_cmap=True)

else:
    # find the max / min value over the inner 100 - alpha percentile range of the data
    scale = np.array([])
    scale = np.append(scale, H_VAR_d01)
    if MAX_DOM == 2:
        scale = np.append(scale, H_VAR_d02)
    scale = scale[~np.isnan(scale.data)]
    alpha = 1
    max_scale, min_scale = np.percentile(scale, [100 - alpha / 2, alpha / 2])
    color_map = sns.color_palette('flare_r', as_cmap=True)
    cnorm = nrm(vmin=min_scale, vmax=max_scale)

if MAX_DOM == 2:
    # NaN out all values of d01 that lie in d02
    H_VAR_d01[data['d02']['indx']] = np.nan

# plot H_VAR as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data['d01']['lons'], y=data['d01']['lats'],
            c=H_VAR_d01,
            alpha=1.000,
            cmap=color_map,
            norm=cnorm,
            marker='.',
            s=20,
            edgecolor='none',
            transform=crs.PlateCarree(),
           )

if MAX_DOM == 2:
    # plot H_VAR as intensity in scatter / heat plot for nested domain
    ax1.scatter(x=data['d02']['lons'], y=data['d02']['lats'],
                c=H_VAR_d02,
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

if C_PL == '' and C_VAR == 'slp':
    # add slp contour plot
    c_var_pl = np.array(data['d01'][C_VAR]).flatten()
    c_var_levels =[1000, 1008, 1016, 1024]

else:
    # add pressure level contour plot
    C_PL = 250
    C_VAR = 'rh'
    c_var_levels = 4
    c_var_pl = data['d01']['pl_' + str(C_PL)][C_VAR].flatten()

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
w_k = 1000
lats = np.array(data['d01']['lats'])
lons = np.array(data['d01']['lons'])
wndx = data['d01']['xx']
wndy = data['d01']['yy']
wndu = data['d01']['pl_' + str(W_PL)]['u'].flatten()
wndv = data['d01']['pl_' + str(W_PL)]['v'].flatten()

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

title1 = anl_dt.strftime('%Y-%m-%dT%H') + r' - ' + str(H_PL) + 'hPa ' + H_VAR + ' / ' +\
        str(W_PL) + 'hPa wind / ' + C_PL + ' ' + C_VAR + ' contours'
title2 = 'fzh - ' + start_dt.strftime('%Y-%m-%dT%H')
plt.figtext(.50, .96, title1, horizontalalignment='center',
        verticalalignment='center', fontsize=22)
plt.figtext(.50, .91, title2, horizontalalignment='center',
        verticalalignment='center', fontsize=22)

fig.savefig(out_path + '/' + CTR_FLW + '_' + anl_dt.strftime('%Y-%m-%dT%H') +\
            '_fzh_' + start_dt.strftime('%Y-%m-%dT%H') + '_' +\
            str(H_PL) + '_' + H_VAR + '_' +\
            str(W_PL) + '_wind_' +\
            str(C_PL) + '_' + C_VAR + '.png')
plt.show()

##################################################################################
# end
