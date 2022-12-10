##################################################################################
# Description
##################################################################################
# This module is designed to centralize the path definitions and assignment of
# different possible control flows for the rocoto workflow manager.  One
# should define the appropriate paths for their system in the GLOBAL PARAMETERS
# below, and specify the appropriate control flow for the task.  Methods in this
# module can be used in other scripts for automating rocoto actions or used
# stand alone in a python sesssion by importing the module.
#
##################################################################################
# License Statement:
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
import os

##################################################################################
# SET GLOBAL PARAMETERS
##################################################################################
# directory for git clone of GSI-WRF-Cycling-Template
USR_HME = '/cw3e/mead/projects/cwp130/scratch/cgrudzien/testing'

# directory for rocoto install
RCT_HME = '/cw3e/mead/projects/cwp130/scratch/cgrudzien'

# name of .xml workflow WITHOUT the extension
#CTR_FLW = '3denvar_wps_perts'
#CTR_FLW = '3denvar_enkf'
CTR_FLW = '3denvar_downscale'
#CTR_FLW = 'ensemble_forecast'
#CTR_FLW = 'deterministic_forecast'

##################################################################################
# Derived paths
##################################################################################
# project directory
PRJ_DIR = USR_HME + '/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR'

# path to rocoto binary root directory
PATHROC = RCT_HME + '/rocoto'

# path to .xml control flows 
flw_dir =  PRJ_DIR + '/control_flows'

# path to database
dbs_dir = PRJ_DIR + '/data'

##################################################################################
# Rocoto utility commands
##################################################################################
# The following commands are wrappers for the native rocoto functions described
# in the documentation:
#
#     http://christopherwharrop.github.io/rocoto/
#
# The rocoto run and stat commands require no arguments and are defined by the
# global parameters in the above sections. For the boot and rewind commands, one
# should supply a list of strings corresponding to the cycle / task names.  One
# can, e.g., loop through ensemble indexed tasks this way with an iterator of
# the form:
#
#    run_rocotoboot(['201902090000'],
#                   ['ungrib_ens_' + str(i).zfill(2) for i in range(21)])
#
# to boot all tasks in a range.
#
##################################################################################

def run_rocotorun():
    cmd = PATHROC + '/bin/rocotorun -w ' +\
          flw_dir + '/' + CTR_FLW + '.xml' +\
          ' -d ' + dbs_dir + '/workflow/' + CTR_FLW + '.store -v 10'  

    os.system(cmd)

def run_rocotostat():
    cmd = PATHROC + '/bin/rocotostat -w ' +\
          flw_dir + '/' + CTR_FLW + '.xml' +\
          ' -d ' + dbs_dir + '/workflow/' + CTR_FLW + '.store -c all'

    os.system(cmd) 

def run_rocotoboot(cycles, tasks):
    # this will loop over the list of cycles and tasks and boot them
    for cycle in cycles:
        for task in tasks:
            cmd = PATHROC + '/bin/rocotoboot -w ' +\
                  flw_dir + '/' + CTR_FLW + '.xml' +\
                  ' -d ' + dbs_dir + '/workflow/' + CTR_FLW + '.store' +\
                  ' -c ' + cycle + ' -t ' + task

            os.system(cmd) 

def run_rocotorewind(cycles, tasks):
    # this will loop over the list of cycles and tasks and rewind them
    for cycle in cycles:
        for task in tasks:
            cmd = PATHROC + '/bin/rocotorewind -w ' +\
                  flw_dir + '/' + CTR_FLW + '.xml' +\
                  ' -d ' + dbs_dir + '/workflow/' + CTR_FLW + '.store' +\
                  ' -c ' + cycle + ' -t ' + task

            os.system(cmd) 

##################################################################################
# end
