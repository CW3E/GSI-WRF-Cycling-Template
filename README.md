# GSI-WRF-Cycling-Template

## Description
This is a template for running GSI-WRF in an offline cycling experiment with the
[Rocoto workflow manager](https://github.com/christopherwharrop/rocoto) and Slurm.
This repository is designed to run a simple cycling experiment as in the
[GSI tutorial](https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/index_v3.7.php)
with the data dependencies for these test cases available there.

This workflow is based on the work of Christopher Harrop, Daniel Steinhoff, Matthew Simpson,
Caroline Papadopoulos, Patrick Mulrooney, et al.  Scripts in this repository were
forked and re-written from examples for WRF ensemble forecasting written by the above
authors.  Variable conventions in this version differ from past versions in order
to smooth the differences between WRF and GSI driver scripts.

Perl wrapper scripts were re-written into Python for preference and extendability in future
versions of this code base.

## Getting started

### Setting up the workflow directory 
In order to run the workflow, you will need the tutorial case data from the
[GSI tutorial](https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/index_v3.7.php).
The cycle-date-dependent data should be copied into the repository as per the directory
structure given below:

```
GSI-WRF-Cycling-Template
|  cycling.xml             -- sets cycle options
|  rocoto.sl               -- runs Slurm job to start / advance Rocoto
|  rocoto_utilities.py     -- defines Rocoto commands to start / advance / query tasks
|  start_rocoto.py         -- called by rocoto.sl to cold start workflow
|  stat_rocoto.py          -- checks status of workflow tasks
|
|--data
|  |--cycle_io
|  |  |--2018081212
|  |  |  |--bkg            -- WRF background files from GSI tutorial
|  |  |  |--gfsens         -- GFS ensemble files from GSI tutorial
|  |  |  |--gsiprd         -- GSI work directory, created by workflow
|  |  |  |--obs            -- observation and prebufr files from GSI tutorial
|  |  |  |--wrfprd         -- WRF run directory created by workflow
|  |  |--2018081218
|  |  |  |--bkg            -- WRF background files from GSI tutorial
|  |  |  |--gsiprd         -- GSI work directory, created by workflow
|  |  |  |--obs            -- observation and prebufr files from GSI tutorial
|  |  |  |--wrfprd         -- WRF run directory created by workflow
|  |--log                  -- contains runtime logs of tasks and workflow
|  |--static
|  |  |  GSI_constants.ksh -- sets environment variables for GSI
|  |  |  gsi.ksh           -- GSI setup / run / postrun driver script
|  |  |  namelist.input    -- WRF settings namelist
|  |  |  WRF_constants.ksh -- sets environment variables for WRF
|  |  |  wrf.ksh           -- WRF setup / run / postrun driver script 
|  |--workflow             -- contains database for workflow status
```


### Directory structure description
The root directory contains the `cycling.xml` file which specifies workflow options to
Rocoto.  Python scripts in this directory wrap Rocoto commands to start, advance and
query the status of workflow tasks.  The core workflow methods are defined in
`rocoto_utilities.py` which are imported into other scripts.  Hard-coded paths are specified
in the `rocoto_utilities.py` and are propagated to other Python commands through importing
these methods.
The workflow will run by submitting the `rocoto.sl` script to the queueing system, which
runs a background job calling `start_rocoto.py` script.
Hard coded paths in the `cycling.xml`, `rocoto_utilities.py` and `rocoto.sl` scripts
should be modified to individual configurations.



### Compiling WRF and GSI
WRF and GSI should each be compiled according to the system environment in which they run.
One should note, the versions of dependencies and compilers may be different between these
compilations as is noted:
<blockquote>
The current release (of GSI) does not build with any of the Intel v19 compilers.
Please use v18 or earlier to compile the code.
</blockquote>
The environment and software specific dependencies / paths should be specified respectively 
in the WRF_constants.ksh and GSI_constants.ksh located 
