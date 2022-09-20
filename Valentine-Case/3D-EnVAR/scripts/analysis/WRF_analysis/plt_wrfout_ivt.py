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
start_date = "2019021000" 

# date for file
date = "2019-02-10_04:00:00"

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

# hard set the ivt magnitude threshold to target ARs
ivtm_min = 250
ivtm_max = 1200
cnorm = nrm(vmin=ivtm_min, vmax=ivtm_max)
color_map = sns.color_palette("flare", as_cmap=True)

# extract ivtm
ivtm_d01 = data["d01"]["ivtm"].flatten()
ivtm_d02 = data["d02"]["ivtm"].flatten()
ivtms = [ivtm_d01, ivtm_d02]

# find the index of values that lie below the ivtm_min
indxs = [[], []]
for i in range(2):
    for k in range(len(ivtms[i])):
        if ivtms[i][k] < ivtm_min:
            indxs[i].append(k)

# NaN out all values of d01 that lie in d02
ivtm_d01[data["d02"]["indx"]] = np.nan

# NaN out all values of both domains that lie below the threshold
ivtm_d01[indxs[0]] = np.nan
ivtm_d02[indxs[1]] = np.nan

# plot ivtm as intensity in scatter / heat plot for parent domain
ax1.scatter(x=data["d01"]["lons"], y=data["d01"]["lats"],
            c=ivtm_d01,
            alpha=0.600,
            cmap=color_map,
            norm=cnorm,
            marker=".",
            s=9,
            edgecolor="none",
            transform=crs.PlateCarree(),
           )

# plot ivtm as intensity in scatter / heat plot for nested domain
ax1.scatter(x=data["d02"]["lons"], y=data["d02"]["lats"],
            c=ivtm_d02,
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

# Add ivt u / v directional barbs plotting every w_kth data point above the threshold
w_k = 7500
lats = np.array(data["d02"]["lats"])
lons = np.array(data["d02"]["lons"])
ivtx = np.array(lons).flatten()
ivty = np.array(lats).flatten()
ivtu = data["d02"]["ivtu"].flatten() 
ivtv = data["d02"]["ivtv"].flatten()

# delete the ivt vectors that fall below the threshold
ivtx = np.delete(ivtx, indxs[1])
ivty = np.delete(ivty, indxs[1])
ivtu = np.delete(ivtu, indxs[1])
ivtv = np.delete(ivtv, indxs[1])


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

title = date + r" - IVT $kg $ $m^{-1} s^{-1}$ " +  c_pl + " " + c_var + " contours"
plt.figtext(.50, .95, title, horizontalalignment='center', verticalalignment='center', fontsize=18)

fig.savefig("./" + start_date + "/start_" + start_date + "_d01_d02_" + date + "_ivt_" +\
            c_pl + "_" + c_var + ".png")
plt.show()
