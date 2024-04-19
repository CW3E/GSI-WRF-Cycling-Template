##################################################################################
# Description
##################################################################################
# This will plot IWV, wind and pressure contour data generated from the companion
# script proc_wrfout_np.py.  The plotting script will null out values of the
# parent domain lying in nested domains, currently only developed for two
# domains.  
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
# define control flow to analyze 
CTR_FLW = 'deterministic_forecast_treatment'

# start date time of WRF forecast in YYYYMMDDHH
START_DT = '2021-01-23_00:00:00'

# analysis date time of inputs / outputs 
ANL_DT = '2021-01-28_00:00:00'

# pressure level for plotting wind barbs
W_PL = 850

# max domain to plot
MAX_DOM = 1

##################################################################################
# Begin plotting
##################################################################################
# convert from iso times
anl_dt = dt.fromisoformat(ANL_DT)
start_dt = dt.fromisoformat(START_DT)

# define derived data paths 
data_root = USR_HME + '/data/analysis/' + CTR_FLW + '/WRF_analysis'
in_path = data_root + '/' + start_dt.strftime('%Y%m%d%H')
out_path = data_root + '/iwv_plots'
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

# hard code the iwv scale to target ARs
iwv_min = 20
iwv_max = 60
color_map = sns.hls_palette(n_colors=40, h=0.68, s=0.9, l=0.55,
        as_cmap=True).reversed()
cnorm = nrm(vmin=iwv_min, vmax=iwv_max)

# extract iwv
iwv_d01 = data['d01']['iwv'].flatten()
if MAX_DOM == 2:
    iwv_d02 = data['d02']['iwv'].flatten()
    iwvs = [iwv_d01, iwv_d02]
else:
    iwvs = [iwv_d01]

# find the index of values that lie below the iwv_min
indxs = [[], []]
for i in range(MAX_DOM):
    for k in range(len(iwvs[i])):
        if iwvs[i][k] < iwv_min:
            indxs[i].append(k)

if MAX_DOM == 2:
    # NaN out all values of d01 that lie in d02
    iwv_d01[data['d02']['indx']] = np.nan

# NaN out all values of both domains that lie below the threshold
iwv_d01[indxs[0]] = np.nan
if MAX_DOM == 2:
    iwv_d02[indxs[1]] = np.nan

# plot iwv as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data['d01']['lons'], y=data['d01']['lats'],
            c=iwv_d01,
            alpha=1.000,
            cmap=color_map,
            norm=cnorm,
            marker='.',
            s=20,
            edgecolor='none',
            transform=crs.PlateCarree(),
           )

if MAX_DOM == 2:
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
w_k = 400
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

title1 = anl_dt.strftime('%Y-%m-%dT%H') + r' - IWV $kg $ $m^{-2}$ / ' + str(W_PL) + 'hPa wind / ' +\
        c_pl + ' ' + c_var + ' contours'
title2 = 'fzh - ' + start_dt.strftime('%Y-%m-%dT%H')
plt.figtext(.50, .96, title1, horizontalalignment='center',
        verticalalignment='center', fontsize=22)
plt.figtext(.50, .91, title2, horizontalalignment='center',
        verticalalignment='center', fontsize=22)

fig.savefig(out_path + '/' + CTR_FLW + '_' + anl_dt.strftime('%Y-%m-%dT%H') +\
            '_fzh_' + start_dt.strftime('%Y-%m-%dT%H') + '_iwv_' +\
             str(W_PL) + '_wind_' + c_var + '.png')
plt.show()

##################################################################################
# end
