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
f_in_path = './processed_numpy'
f_out_path = './processed_numpy/ivt_plots'
start_date = '2019021400' 
os.system('mkdir -p ' + f_out_path)

# date for file
date = '2019-02-14_00:00:00'

# load data
f = open(f_in_path + '/' + start_date + '/start_' + start_date + '_forecast_' + date + '.txt', 'rb')
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
ax3 = fig.add_axes([0.0, .05, .8, .05], frameon=False)

# hard set the ivt magnitude threshold to target ARs
ivtm_min = 250
ivtm_max = 1200
cnorm = nrm(vmin=ivtm_min, vmax=ivtm_max)
color_map = sns.color_palette('flare', as_cmap=True)

# extract ivtm
ivtm_d01 = data['d01']['ivtm'].flatten()
ivtm_d02 = data['d02']['ivtm'].flatten()
ivtms = [ivtm_d01, ivtm_d02]

# find the index of values that lie below the ivtm_min
indxs = [[], []]
for i in range(2):
    for k in range(len(ivtms[i])):
        if ivtms[i][k] < ivtm_min:
            indxs[i].append(k)

# NaN out all values of d01 that lie in d02
ivtm_d01[data['d02']['indx']] = np.nan

# NaN out all values of both domains that lie below the threshold
ivtm_d01[indxs[0]] = np.nan
ivtm_d02[indxs[1]] = np.nan

# plot ivtm as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data['d01']['lons'], y=data['d01']['lats'],
            c=ivtm_d01,
            alpha=0.600,
            cmap=color_map,
            norm=cnorm,
            marker='.',
            s=9,
            edgecolor='none',
            transform=crs.PlateCarree(),
           )

# plot ivtm as intensity in scatter / heat plot for nested domain
ax1.scatter(x=data['d02']['lons'], y=data['d02']['lats'],
            c=ivtm_d02,
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

# add pressure level contour plot
#c_pl = 250
#c_var = 'rh'
#c_var_levels = 4
#c_var_pl = data['d01']['pl_' + str(c_pl)][c_var].flatten()

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

# Add ivt u / v directional barbs plotting every w_kth data point above the threshold
w_k = 4000
lats = np.array(data['d01']['lats'])
lons = np.array(data['d01']['lons'])
ivtx = np.array(lons).flatten()
ivty = np.array(lats).flatten()
ivtu = data['d01']['ivtu'].flatten() 
ivtv = data['d01']['ivtv'].flatten()

# delete the ivt vectors that fall below the threshold
ivtx = np.delete(ivtx, indxs[0])
ivty = np.delete(ivty, indxs[0])
ivtu = np.delete(ivtu, indxs[0])
ivtv = np.delete(ivtv, indxs[0])


barb_incs = {
             'half':50,
             'full':100,
             'flag':500,
            }

ax1.barbs(
          ivtx[int(w_k/2)::w_k], ivty[int(w_k/2)::w_k],
          ivtu[int(w_k/2)::w_k], ivtv[int(w_k/2)::w_k],
          transform=crs.PlateCarree(), 
          length=7,
          barb_increments=barb_incs,
         )
# create barb legend
ax3.barbs(
        [0, 0.5, 1],
        [0, 0, 0],
        [50, 100, 500],
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

ax3.text(0.02, 0, 'IVT Magnitude 50',  {'fontsize': 18})
ax3.text(0.52, 0, 'IVT Magnitude 100', {'fontsize': 18})
ax3.text(1.02, 0, 'IVT Magnitude 500', {'fontsize': 18})

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

# make title and save figure
d1 = copy.copy(start_date)
d1 = d1[:4] + ':' + d1[4:6] + ':' + d1[6:8] + '_' + d1[8:] + ':00:00'

title1 = date + r' - IVT $kg $ $m^{-1} s^{-1}$ ' +  c_pl + ' ' + c_var + ' contours'
title2 = 'fzh ' + d1

plt.figtext(.50, .96, title1, horizontalalignment='center', verticalalignment='center', fontsize=22)
plt.figtext(.50, .91, title2, horizontalalignment='center', verticalalignment='center', fontsize=22)

fig.savefig(f_out_path + '/' + date + '_fzh_' + d1 + '_ivt_' +\
            c_pl + '_' + c_var + '.png')
plt.show()
