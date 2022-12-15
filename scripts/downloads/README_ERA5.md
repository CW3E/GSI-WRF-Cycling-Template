# ERA5 Data Pull Scripts
These scripts will pull ECMWF ERA5 reanalysis grib data that can be used as an input for
WRF using a standard work flow as in the
[WRF tutorial](https://www2.mmm.ucar.edu/wrf/OnLineTutorial/CASES/SingleDomain/index.php).

Surface level fields are necessary, as is one of the 38 pressure level data or the 138
model level data.  These are each downloaded according to their respective script, where
one needs to obtain an account with
```
https://cds.climate.copernicus.eu/#!/home
```
and enter the credentials into the download scripts.  Dependencies can be installed
in a conda environment according to the import statements in the header.

## Surface levels
This is necessary for combining with either of the pressure level or model level data.

## Pressure levels
Comine pressure level grib files and surface level files in a single directory and link
for WPS with
```
./link_grib.csh path_to_files
```
Ungribbing with the 
```
Vtable.ERA-interim.pl
```
vtable.  This can be followed with metgrid.exe and real.exe as in the WRF tutorial to 
set up the initialization of the model.

## Model levels
This requires a preprocessing step using eccodes
```
conda install -c conda-forge eccodes
```
After installing, the `pre_process.sh` can be run to output the model level data into
grib1 files that are compatible with the Vtable
```
Vtable.ERA-ml-hybrid
```
The file of ECMWF coefficients
```
ecmwf_coeffs
```
should be included in the WPS directory, and then additional intermediate files can be created by
running
```
./util/calc_ecmwf_p.exe
```
These intermediate files are prefixed with `PRES`, so that the namelist.wps needs to have both
file prefixes to process the ungribbed files together with the newly created files in Metgrid:
```
&metgrid
fg_name = 'FILE','PRES'
io_form_metgrid = 2,
```
Running this with `metgrid.exe`, the same procedure using `real.exe` in the WRF run directory can be
followed as with the WRF tutorial. 
