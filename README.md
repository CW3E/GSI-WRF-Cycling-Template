# GSI-WRF-Cycling-Template

[![Total lines of code without comments](https://tokei.rs/b1/github/CW3E/GSI-WRF-Cycling-Template?category=code)](https://github.com/CW3E/GSI-WRF-Cycling-Template)

## Description
This is a template for running GSI-WRF in an offline cycling experiment with the
[Rocoto workflow manager](https://github.com/christopherwharrop/rocoto) and Slurm.
This repository is designed to run a simple cycling experiment as in the
[GSI tutorial (case 6)](https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/index_v3.7.php)
with the data dependencies for this test case available there.

This workflow is based on the work of Christopher Harrop, Daniel Steinhoff, Matthew Simpson,
Caroline Papadopoulos, Patrick Mulrooney, Minghua Zheng, et al.  Scripts in this repository were
forked and re-written from examples for WRF ensemble forecasting written by the above
authors.  Variable conventions in this version differ from past versions in order
to smooth the differences between WRF and GSI driver scripts.
Perl wrapper scripts were re-written into Python for preference and extendability in future
versions of this code base.

Currently, this template is limited to only a basic set of tutorial / test cases for GSI,
though new features are expected to be included in future versions, in order to handle
more realistic cycling experiments.  The focus of this workflow development is to perform offline
research experiments, not real-time forecast cycles.  Please see other workflow templates
for this purpose.

## Getting started

### Setting up workflow directories 

A basic schema of the cycling workflow directory heirarchy is pictured below:
```
GSI-WRF-Cycling-Template
|  cycling.xml                -- sets cycle options
|  rocoto.sl                  -- runs Slurm job to start / advance Rocoto
|  rocoto_utilities.py        -- Rocoto commands to start / advance / query tasks
|  start_rocoto.py            -- called by rocoto.sl to cold start workflow
|  stat_rocoto.py             -- checks status of workflow tasks
|
|--data
|  |--workflow                -- contains database for workflow status
|  |--log                     -- contains runtime logs of tasks and workflow
|  |--cycle_io                -- cycle date observation / analysis / forecast files 
|  |  |--2018081212
|  |  |  |--bkg               -- WRF background files from GSI tutorial
|  |  |  |--obs               -- observation and prebufr files from GSI tutorial
|  |  |  |--gfsens            -- GFS ensemble files from GSI tutorial
|  |  |  |--gsiprd            -- GSI work directory, created by workflow
|  |  |  |--wrfprd            -- WRF run directory created by workflow
|  |  |--2018081218
|  |  |  |--bkg               -- WRF background files from GSI tutorial
|  |  |  |--obs               -- observation and prebufr files from GSI tutorial
|  |  |  |--gsiprd            -- GSI work directory, created by workflow
|  |  |  |--wrfprd            -- WRF run directory created by workflow
|  |--static
|  |  |  GSI_constants.ksh    -- sets environment variables for GSI
|  |  |  gsi.ksh              -- GSI setup / run / postrun driver script
|  |  |  WRF_constants.ksh    -- sets environment variables for WRF
|  |  |  wrf.ksh              -- WRF setup / run / postrun driver script 
|  |  |  namelist.input       -- WRF settings namelist from GSI tutorial
|  |  |--build_examples       -- contains example build scripts for GSI / WRF
|  |  |  |  configure.wrf-4.4 -- WRF COMET configuration options
|  |  |  |  GSI_cmake_make.sh -- GSI COMET build script
|  |  |  |  WRF_conf_comp.sh  -- WRF COMET build script
```
The basic directory structure can be extended to arbitrary numbers of cycles provided the
needed data for observations, boundary and initial conditions for generating the 
observation-analysis-forecast cycle.  Additional directories for products from WPS and
`real.exe` can likewise be included in this heirarchy, and integrated with further
driver scripts and tasks in the workflow.  Extensions to this workflow to include 
`ungrib.exe`, `geogrid.exe`, `metgrid.exe`, `real.exe` and other tasks are expected in future
versions.

#### Tutorial data
In order to run the workflow, you will need the
[GSI tutorial
case data](https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/releaseV3.7/data/download_data.php).
The cycle-date-dependent data should be copied into the repository as per the directory
structure given above. Tutorial data tar files contain the needed `bkg`, `gfsens`
and `obs` directories above, organized by cycle date.  The `data/static/namelist.input`
should be copied from the `2018081218/bkg/namelist.input` of the tutorial data.

#### Root
The root directory contains the `cycling.xml` file which specifies workflow options to
Rocoto.  Python scripts in this directory wrap Rocoto commands to start, advance and
query the status of workflow tasks.  The core workflow methods are defined in
`rocoto_utilities.py` which are imported into other scripts.  Hard-coded paths are specified
centrally in the `rocoto_utilities.py` and are propagated to other Python commands through
importing these methods.  The workflow will run by submitting the `rocoto.sl` script to
the queueing system, which runs a background job calling `start_rocoto.py` script.
Hard-coded paths in the `cycling.xml`, `rocoto_utilities.py` and `rocoto.sl` scripts
should be modified to individual configurations, including the locations of Rocoto, WRF and GSI
builds.

#### Building Rocoto
Rocoto can be cloned directly from the [Github repository](https://github.com/christopherwharrop/rocoto)
in order to obtain the latest version.  The `rocoto/INSTALL` script can be run to install Rocoto on
the system in a local or a centralized version.  Complete documentation on using Rocoto can be found
on the [project webpage](http://christopherwharrop.github.io/rocoto/).  The root directory of the
Rocoto install containing the binaries sub-directory needs to be set equal to the variable
`pathroc` in the `rocoto_utilities.py` module.  This workflow is currently tested and validated
for Rocoto versions 1.3.3 and 1.3.4.


#### Building WRF and GSI
WRF can be cloned directly from the [Github repository](https://github.com/wrf-model/WRF) though
users are encouraged to register on the [WRF users registration
page](https://www2.mmm.ucar.edu/wrf/users/download/wrf-regist.php).  GSI can be obtained from the
[Community GSI Users Page](https://dtcenter.ucar.edu/com-GSI/users/downloads/index.php).
WRF and GSI should each be compiled according to the system environment in which they run.
One should note, the versions of dependencies and compilers may be different between these
compilations:
<blockquote>
The current release (of GSI) does not build with any of the Intel v19 compilers.
Please use v18 or earlier to compile the code.
</blockquote>
This workflow has been tested and validated with WRF versions 4.3 / 4.4, and with GSI version 3.7.

The environment and software specific dependencies / paths should be defined 
in the `WRF_constants.ksh` and `GSI_constants.ksh` respectively, both located in the 
`data/static/` directory.  Example configuration / build scripts for WRF and GSI are
in the `data/static/build_examples` directory with options matching those in the
`*_constants.ksh` scripts.  This workflow assumes that one is linking WRF files from a "clean"
`WRF/run` directory.  Namelists, inputs, outputs and boundary data for WRF runs should be
removed in advanced to "clean" the run directory in order to minimize the chance of
unexpected conflicts.  This workflow furthermore assumes that one keeps their root directory
for their CRTM binaries as a sub-directory of the root of the GSI build, e.g., as
```
comGSIv3.7_EnKFv1.3
|  build
|  CRTM_v2.3.0
|  fix
|  libsrc
|  src
|  ush
|  util
```
where the `GSI_ROOT` path and the `CRTM_VERSION` is specified in the `cycling.xml` workflow options. 

### Running the test case 
Assuming that all local configuration options have been set in the above scripts,
the test case can be run by submitting `rocoto.sl` to the scheduler.  This will begin a
3D-VAR, offline observation-analysis-forecast cycle.  This begins with the GSI analysis of
the provided background data / observation for `2018081212`, generating outputs in the
`data/cycling_io/2018081212/gsiprd` directory.  When this task is completed, a forecast
is generated with WRF from the initial conditions defined by the `wrf_inout` output of
the GSI task.  This is linked automatically from the `gsiprd` directory into the 
`wrfprd` directory in the `wrf.ksh` driver script.  NOTE: this is currently only designed
for a single domain as in the tutorial, with future versions of this workflow to include a
more generalized template for realistic cycling experiments.
The `wrf.ksh` script creates a `bkg` directory for the next cycle date if it
does not already exist and link its outputs into this directory for the next GSI analysis.
Additional workflow tasks may be included in the future to automate the generation of the
`obs` directory with the needed observation data.

The `gsi` workflow task is submitted upon the completion of the last cycle's `wrf` task,
thus beginning a new cycle of the workflow.  Because this condition is never satisfied for
the first cycle, the `start_rocoto.py` script will use both of the `run_rocotorun` and
`run_rocotoboot` methods in the `rocoto_utilities.py` module to begin a cold start of the
workflow.  However, the `run_rocotoboot` method can also be used to restart a cycle-task
for debugging and testing.  The `run_rocotostat` method in the `rocoto_utilities.py` module
automates the check status command for Rocoto, so that this can be used by calling
`python stat_rocoto.py`
to check the status of the workflow, or used directly as with the other utitlies in a Python
session.

The full cycling experiment will complete with the forecast initialized from the analyzed state at
`2018081212`, where the `wrf.ksh` script will create a `2018081300` directory with new `bkg` files
to initate a new cycle.

## Known issues
See the Github issues page for ongoing issues / debugging efforts with this template.

## Posting issues
If you encounter bugs, please post a detailed issue in the Github page, with steps and parameter
settings that reproduce this issue, and please include any related error messages / logs that
may be useful for solving this.  Limited support and debugging will be performed for issues that do
not adhere to this request.

## Fixing issues
If you encounter a bug and have a solution, please follow the same steps as above to post the issue
and then submit a pull request with your branch that fixes the issue with a detailed explanation of
the solution.
