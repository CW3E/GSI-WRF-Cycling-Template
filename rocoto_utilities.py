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

# Case study sub directories
CSES = [
        #'CC',
        'VD',
       ]

# name of .xml workflows to execute and monitor WITHOUT the extension of file
CTR_FLWS = [
            ## NOTE -- these are already covered   ##
            ## with defaul settings for old config ##
            ## '3denvar_lag00_b0.00_v03_h0300',    ##
            ## '3denvar_lag06_b0.00_v03_h0300',    ##
            ## END NOTE                            ##
            '3denvar_lag00_b0.00_v03_h0150',
            '3denvar_lag00_b0.00_v03_h0450',
            '3denvar_lag00_b0.00_v03_h0600',
            '3denvar_lag00_b0.00_v03_h0900',
            '3denvar_lag06_b0.00_v03_h0150',
            '3denvar_lag06_b0.00_v03_h0450',
            '3denvar_lag06_b0.00_v03_h0600',
            '3denvar_lag06_b0.00_v03_h0900',
            'deterministic_forecast_lag00_b0.00_v03_h0150',
            'deterministic_forecast_lag00_b0.00_v03_h0450',
            'deterministic_forecast_lag00_b0.00_v03_h0600',
            'deterministic_forecast_lag00_b0.00_v03_h0900',
            'deterministic_forecast_lag06_b0.00_v03_h0150',
            'deterministic_forecast_lag06_b0.00_v03_h0450',
            'deterministic_forecast_lag06_b0.00_v03_h0600',
            'deterministic_forecast_lag06_b0.00_v03_h0900',
            #'3denvar_lag00_b0.00_v06_h0150',
            #'3denvar_lag00_b0.00_v06_h0300',
            #'3denvar_lag00_b0.00_v06_h0450',
            #'3denvar_lag00_b0.00_v06_h0600',
            #'3denvar_lag00_b0.00_v06_h0900',
            #'3denvar_lag06_b0.00',
            #'3denvar_lag06_b0.10',
            #'3denvar_lag06_b0.20',
            #'3denvar_lag06_b0.30',
            #'3denvar_lag06_b0.40',
            #'3denvar_lag06_b0.60',
            #'3denvar_lag06_b0.70',
            #'3denvar_lag06_b0.80',
            #'3denvar_lag06_b0.90',
           ]

##################################################################################
# Derived paths
##################################################################################
# path to rocoto binary root directory
pathroc = RCT_HME + '/rocoto'

# path to .xml control flows 
settings_dir =  USR_HME + '/simulation_settings'

# path to database
dbs_dir = USR_HME + '/workflow_status'

##################################################################################
# Rocoto utility commands
##################################################################################
# The following commands are wrappers for the native rocoto functions described
# in its documentation:
#
#     http://christopherwharrop.github.io/rocoto/
#
# The rocoto run and stat commands require no arguments and are defined by the
# global parameters in the above sections. For the boot and rewind commands, one
# should supply a list of strings corresponding to the control flow, cycle date
# time and the corresponding task names to boot or rewind.  One can, e.g., loop
# through ensemble indexed tasks this way with an iterator of the form:
#
#    run_rocotoboot(
#                   ['3denvar_test_run'],
#                   ['201902081800'],
#                   ['ungrib_ens_' + str(i).zfill(2) for i in range(21)]
#                  )
#
# to boot all tasks in a range for a specified date and control flow.
#
##################################################################################

def run_rocotorun():
    for cse in CSES:
        for ctr_flw in CTR_FLWS:
            cmd = pathroc + '/bin/rocotorun -w ' +\
                  settings_dir + '/' + cse + '/' + ctr_flw + '/' + ctr_flw + '.xml' +\
                  ' -d ' + dbs_dir + '/' + cse + '-' + ctr_flw + '.store -v 10'  

            os.system(cmd)

        # update workflow statuses after loops
        run_rocotostat()

def run_rocotostat():
    for cse in CSES:
        for ctr_flw in CTR_FLWS:
            cmd = pathroc + '/bin/rocotostat -w ' +\
                  settings_dir + '/' + cse + '/' + ctr_flw + '/' + ctr_flw + '.xml' +\
                  ' -d ' + dbs_dir + '/' + cse + '-' + ctr_flw + '.store -c all'+\
                  ' > ' + dbs_dir + '/' + cse + '-' + ctr_flw + '_workflow_status.txt'

            os.system(cmd) 

def run_rocotoboot(cses, flows, cycles, tasks):
    for cse in cses:
        for ctr_flw in flows:
            for cycle in cycles:
                for task in tasks:
                    cmd = pathroc + '/bin/rocotoboot -w ' +\
                          settings_dir + '/' + cse + '/' + ctr_flw + '/' + ctr_flw + '.xml' +\
                          ' -d ' + dbs_dir + '/' + cse + '-' + ctr_flw + '.store' +\
                          ' -c ' + cycle + ' -t ' + task

                    os.system(cmd) 

        # update workflow statuses after loops
        run_rocotostat()

def run_rocotorewind(cses, flows, cycles, tasks):
    for cse in cses:
        for ctr_flw in flows:
            for cycle in cycles:
                for task in tasks:
                    cmd = pathroc + '/bin/rocotorewind -w ' +\
                          settings_dir + '/' + cse + '/' + ctr_flw + '/' + ctr_flw + '.xml' +\
                          ' -d ' + dbs_dir + '/' + cse + '-' + ctr_flw + '.store' +\
                          ' -c ' + cycle + ' -t ' + task

                    os.system(cmd) 

        # update workflow statuses after loops
        run_rocotostat()

##################################################################################
# Execute the following lines as script
##################################################################################

if __name__ == '__main__':
    # monitor and advance the jobs
    while (True):
        run_rocotorun()
        time.sleep(60)

##################################################################################
# end
