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

# heat plot pressure level and variable
h_pl = 925
h_var = "temp"

# file paths
f_in_path = "./processed_3d_fields/"
start_date_1 = "2019021400" 
start_date_2 = "2019021412" 

# date for files
date = "2019-02-14_16:00:00"

# load data file 1 which is used as the reference data
f_1 = open(f_in_path + "proc_wrfout_start_" + start_date_1 + "_model_time_" + date + "_3D_vars.txt", "rb")
data = pickle.load(f_1)
f_1.close()

# load data file 2 which we compute divergence with
f_2 = open(f_in_path + "proc_wrfout_start_" + start_date_2 + "_model_time_" + date + "_3D_vars.txt", "rb")
data_diff = pickle.load(f_2)
f_2.close()

# load the projection
cart_proj = data["cart_proj"]

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the GeoAxes to the projection used by WRF
ax0 = fig.add_axes([.875, .10, .05, .8])
ax1 = fig.add_axes([.05, .10, .8, .8], projection=cart_proj)

# unpack variables and compute the divergence from f_1
h1_var_d01 = data["d01"]["pl_" + str(h_pl)][h_var].flatten()
h1_var_d02 = data["d02"]["pl_" + str(h_pl)][h_var].flatten()

h2_var_d01 = data_diff["d01"]["pl_" + str(h_pl)][h_var].flatten()
h2_var_d02 = data_diff["d02"]["pl_" + str(h_pl)][h_var].flatten()

h_diff_d01 = h2_var_d01 - h1_var_d01
h_diff_d02 = h2_var_d02 - h1_var_d02

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
if h_var == "rh":
    abs_scale = 50
    color_map = sns.diverging_palette(220, 20, as_cmap=True)

elif h_var == "temp":
    abs_scale = 2.0
    color_map = sns.diverging_palette(150, 30, l=65, as_cmap=True)

else:
    # make the scales of d01 / d02 equivalent in color map
    scale = np.append(h_diff_d01.data, h_diff_d02.data)
    scale = scale[~np.isnan(scale.data)]
    
    # find the max / min value over the inner 100 - alpha percentile range of the data
    alpha = 1
    max_scale, min_scale = np.percentile(scale, [100 - alpha / 2, alpha / 2])
    
    # find the largest magnitude divergence of the above data
    abs_scale = np.max([abs(max_scale), abs(min_scale)])
    color_map = sns.diverging_palette(300, 20, l=55, as_cmap=True)

# make a symmetric color map about zero
cnorm = nrm(vmin=-abs_scale, vmax=abs_scale)

# replace above definition to use an asymmetric color map
#color_map = sns.color_palette("vlag", as_cmap=True)
#cnorm = MidpointNormalize(vmin=min_scale, vmax=max_scale, midpoint=0.0)

# NaN out all values of d01 that lie in d02
h_diff_d01[data["d02"]["indx"]] = np.nan

# plot h_var as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data["d01"]["lons"], y=data["d01"]["lats"],
            c=h_diff_d01.data,
            #alpha=0.600,
            cmap=color_map,
            norm=cnorm,
            marker=".",
            s=9,
            edgecolor="none",
            transform=crs.PlateCarree(),
           )

# plot h_var as intensity in scatter / heat plot for nested domain
ax1.scatter(x=data["d02"]["lons"], y=data["d02"]["lats"],
            c=h_diff_d02.data,
            #alpha=0.600,
            cmap=color_map,
            norm=cnorm,
            marker=".",
            s=1,
            edgecolor="none",
            transform=crs.PlateCarree(),
           )

# bottom boundary
ax1.plot(
         [data["d02"]["x_lim"][0], data["d02"]["x_lim"][1]],
         [data["d02"]["y_lim"][0], data["d02"]["y_lim"][0]],
         linestyle="-",
         linewidth=1.5,
         color="k",
        )

# top boundary
ax1.plot(
         [data["d02"]["x_lim"][0], data["d02"]["x_lim"][1]],
         [data["d02"]["y_lim"][1], data["d02"]["y_lim"][1]],
         linestyle="-",
         linewidth=1.5,
         color="k",
        )

# left boundary
ax1.plot(
         [data["d02"]["x_lim"][0], data["d02"]["x_lim"][0]],
         [data["d02"]["y_lim"][0], data["d02"]["y_lim"][1]],
         linestyle="-",
         linewidth=1.5,
         color="k",
        )

# right boundary
ax1.plot(
         [data["d02"]["x_lim"][1], data["d02"]["x_lim"][1]],
         [data["d02"]["y_lim"][0], data["d02"]["y_lim"][1]],
         linestyle="-",
         linewidth=1.5,
         color="k",
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
ax1.set_xlim(data["d01"]["x_lim"])
ax1.set_ylim(data["d01"]["y_lim"])

# Add the gridlines
ax1.gridlines(color="black", linestyle="dotted")

# make title and save figure
title = date + " - " + h_var + " " + str(h_pl) + " divergence plot"
plt.figtext(.50, .95, title, horizontalalignment='center', verticalalignment='center', fontsize=18)
plt.savefig("./diff_plots/d01_d02_" + date + "_pl_" + str(h_pl) + "_" + h_var + "_diff_plot.png")
plt.show()
