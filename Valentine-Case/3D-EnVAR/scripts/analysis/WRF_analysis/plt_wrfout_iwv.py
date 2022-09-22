import matplotlib.pyplot as plt
from matplotlib.colors import Normalize as nrm
from matplotlib.cm import get_cmap
from matplotlib.colorbar import Colorbar as cb
import seaborn as sns
import cartopy.crs as crs
import cartopy.feature as cfeature
import numpy as np
import pickle

# file paths
f_in_path = "./processed_3d_fields/"
start_date = "2019021412" 

# date for file
date = "2019-02-14_16:00:00"

# load data
f = open(f_in_path + "proc_wrfout_start_" + start_date + "_model_time_" + date + "_3D_vars.txt", "rb")
data = pickle.load(f)
f.close()

# load the projection
cart_proj = data["cart_proj"]

# Create a figure
fig = plt.figure(figsize=(11.25,8.63))

# Set the GeoAxes to the projection used by WRF
ax0 = fig.add_axes([.875, .10, .05, .8])
ax1 = fig.add_axes([.05, .10, .8, .8], projection=cart_proj)
ax2 = fig.add_axes([.05, .10, .8, .8], frameon=False)

# make the scales of d01 / d02 equivalent in color map
iwv_d01 = data["d01"]["iwv"].flatten()
iwv_d02 = data["d02"]["iwv"].flatten()

# hard code the iwv scale
min_scale = 0
max_scale = 65
color_map = sns.color_palette("flare_r", as_cmap=True)
cnorm = nrm(vmin=min_scale, vmax=max_scale)

# NaN out all values of d01 that lie in d02
iwv_d01[data["d02"]["indx"]] = np.nan

# plot iwv as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data["d01"]["lons"], y=data["d01"]["lats"],
            c=iwv_d01,
            alpha=0.600,
            cmap=color_map,
            norm=cnorm,
            marker=".",
            s=9,
            edgecolor="none",
            transform=crs.PlateCarree(),
           )

# plot iwv as intensity in scatter / heat plot for nested domain
ax1.scatter(x=data["d02"]["lons"], y=data["d02"]["lats"],
            c=iwv_d02,
            alpha=0.600,
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


# add slp contour plot
c_pl = ""
c_var = "slp"
c_var_pl = np.array(data["d01"][c_var]).flatten()
c_var_levels =[1000, 1008, 1016, 1024]

# add pressure level contour plot
#c_pl = 250
#c_var = "rh"
#c_var_levels = 4
#c_var_pl = data["d01"]["pl_" + str(c_pl)][c_var].flatten()

# shape contour data for contour function in x / y coordinates
lats = np.array(data["d01"]["lats"])
lons = np.array(data["d01"]["lons"])
c_indx = np.shape(np.array(lons))
c_var_pl = np.reshape(c_var_pl, c_indx)
xx = np.reshape(data["d01"]["xx"], c_indx)
yy = np.reshape(data["d01"]["yy"], c_indx)

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
                 colors="black",
                 linestyles="dashdot",
                 levels=c_var_levels,
                )

ax2.clabel(CS, CS.levels, inline=True, fontsize=12)

# add geog / cultural features
ax1.add_feature(cfeature.COASTLINE)
ax1.add_feature(cfeature.STATES)
ax1.add_feature(cfeature.BORDERS)

# Add wind barbs plotting every w_kth data point, starting from w_k/2
w_k = 240
w_pl = 850
lats = np.array(data["d02"]["lats"])
lons = np.array(data["d02"]["lons"])
u_pl = np.array(data["d02"]["pl_" + str(w_pl)]["u"])
v_pl = np.array(data["d02"]["pl_" + str(w_pl)]["v"])
ax1.barbs(np.array(lons[int(w_k/2)::w_k, int(w_k/2)::w_k]), np.array(lats[int(w_k/2)::w_k, int(w_k/2)::w_k]),
          np.array(u_pl[int(w_k/2)::w_k, int(w_k/2)::w_k]), np.array(v_pl[int(w_k/2)::w_k, int(w_k/2)::w_k]),
          transform=crs.PlateCarree(), length=7)

# Add a color bar
cb(ax=ax0, cmap=color_map, norm=cnorm)
ax1.tick_params(
    labelsize=16,
    )

# Set the map bounds
ax1.set_xlim(data["d01"]["x_lim"])
ax1.set_ylim(data["d01"]["y_lim"])
ax2.set_xlim([x_min, x_max])
ax2.set_ylim([y_min, y_max])

# Add the gridlines
ax1.gridlines(color="black", linestyle="dotted")

title = date + " - iwv / " + str(w_pl) + " wind / " +  c_pl + " " + c_var + " contours"
plt.figtext(.50, .95, title, horizontalalignment='center', verticalalignment='center', fontsize=18)

fig.savefig("./" + start_date + "/start_" + start_date + "_d01_d02_" + date + "_iwv_" + str(w_pl) + "_wind_" +\
            c_pl + "_" + c_var + ".png")
plt.show()
