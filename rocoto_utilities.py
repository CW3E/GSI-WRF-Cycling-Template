##################################################################################
# Description
##################################################################################
# This module is designed to centralize the path definitions and assignment of
# different possible control flows for the rocoto workflow manager.  One
# should define the appropriate paths for their system in the GLOBAL PARAMETERS
# below, and specify the appropriate control flows for the tasks to be run and
# monitored. Methods in this module can be used in other scripts for automating
# rocoto actions, used stand alone by calling actions in the bottom script
# section, or directly as functions in a Python session by importing the module.
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
import time

##################################################################################
# SET GLOBAL PARAMETERS
##################################################################################
# directory path for root of git clone of GSI-WRF-Cycling-Template
USR_HME = '/cw3e/mead/projects/cwp106/scratch/GSI-WRF-Cycling-Template'

# directory for rocoto install
RCT_HME = '/cw3e/mead/projects/cwp130/scratch/cgrudzien'

# name of .xml workflows to execute and monitor WITHOUT the extension of file
CTR_FLWS =[
           'common_case_3dvar',
           #'common_case_3denvar_wps_perts',
           #'common_case_3denvar_enkf',
           #'common_case_3denvar_downscale',
           #'common_case_ensemble_forecast',
           #'common_case_deterministic_forecast',
          ]

##################################################################################
# Derived paths
##################################################################################
# path to rocoto binary root directory
pathroc = RCT_HME + '/rocoto'

# path to .xml control flows 
flw_dir =  USR_HME + '/simulation_settings/control_flows'

# path to database
dbs_dir = USR_HME + '/workflow_status'

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
#    run_rocotoboot(
#                   ['3denvar_downscale'],
#                   ['201902090000'],
#                   ['ungrib_ens_' + str(i).zfill(2) for i in range(21)]
#                  )
#
# to boot all tasks in a range for a specified date and control flow.
#
##################################################################################

def run_rocotorun():
    for ctr_flw in CTR_FLWS:
        cmd = pathroc + '/bin/rocotorun -w ' +\
              flw_dir + '/' + ctr_flow + '.xml' +\
              ' -d ' + dbs_dir + '/' + ctr_flow + '.store -v 10'  

        os.system(cmd)

def run_rocotostat():
    for ctr_flw in CTR_FLWS:
        cmd = pathroc + '/bin/rocotostat -w ' +\
              flw_dir + '/' + ctr_flow + '.xml' +\
              ' -d ' + dbs_dir + '/' + ctr_flow + '.store -c all'+\
              ' > ' + dbs_dir + '/' + ctr_flow + '_workflow_status.txt'

        os.system(cmd) 

def run_rocotoboot(flows, cycles, tasks):
    for ctr_flw in flows:
        for cycle in cycles:
            for task in tasks:
                cmd = pathroc + '/bin/rocotoboot -w ' +\
                      flw_dir + '/' + ctr_flow + '.xml' +\
                      ' -d ' + dbs_dir + '/' + ctr_flow + '.store' +\
                      ' -c ' + cycle + ' -t ' + task

                os.system(cmd) 

def run_rocotorewind(flows, cycles, tasks):
    for ctr_flw in flows:
        for cycle in cycles:
            for task in tasks:
                cmd = pathroc + '/bin/rocotorewind -w ' +\
                      flw_dir + '/' + ctr_flow + '.xml' +\
                      ' -d ' + dbs_dir + '/' + ctr_flow + '.store' +\
                      ' -c ' + cycle + ' -t ' + task

                os.system(cmd) 

##################################################################################
# Execute the following lines as script
##################################################################################

if __name__ == '__main__':
    # monitor and advance the jobs
    while (True):
        run_rocotorun()
        run_rocotostat()
        time.sleep(60)

##################################################################################
# end
