##################################################################################
# Description
##################################################################################
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
# directory for git clone
USR_HME = '/cw3e/mead/projects/cwp130/scratch/cgrudzien'

# project directory
PRJ_DIR = USR_HME + '/GSI-WRF-Cycling-Template/Valentine-Case/3D-EnVAR'

# name of .xml workflow WITHOUT the extension
#CTR_FLW = '3denvar_wps_perts'
#CTR_FLW = '3denvar_enkf'
#CTR_FLW = '3denvar_downscale'
#CTR_FLW = 'ensemble_forecast'
CTR_FLW = 'deterministic_forecast'

# path to rocoto binary root directory
PATHROC = USR_HME + '/rocoto'

##################################################################################
# Derived paths
##################################################################################
# path to .xml control flows 
flw_dir =  PRJ_DIR + '/control_flows'

# path to database
dbs_dir = PRJ_DIR + '/data'

##################################################################################
# Rocoto utility commands
##################################################################################
# The following commands are wrappers for the native rocoto functions described
# in the documentation http://christopherwharrop.github.io/rocoto/

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

def run_rocotoboot(cycle, task_list):
    cmd = PATHROC + '/bin/rocotoboot -w ' +\
          flw_dir + '/' + CTR_FLW + '.xml' +\
          ' -d ' + dbs_dir + '/workflow/' + CTR_FLW + '.store' +\
          ' -c ' + cycle + ' -t ' + task_list

    os.system(cmd) 

def run_rocotorewind(cycle, task_list):
    cmd = PATHROC + '/bin/rocotorewind -w ' +\
          flw_dir + '/' + CTR_FLW + '.xml' +\
          ' -d ' + dbs_dir + '/workflow/' + CTR_FLW + '.store' +\
          ' -c ' + cycle + ' -t ' + task_list

    os.system(cmd) 

##################################################################################
# end
