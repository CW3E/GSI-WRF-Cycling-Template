##################################################################################
# License Statement:
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
# imports
import os

##################################################################################
# utility global variables

# path to .xml workflow
pathnam = "/cw3e/mead/projects/cwp106/scratch/cgrudzien/GSI-WRF-Cycling-Template"

# name of .xml workflow
wrknam = "cycling"

# path to database
outnam = "/cw3e/mead/projects/cwp106/scratch/cgrudzien/" +\
         "GSI-WRF-Cycling-Template/data"

# path to rocoto binary root directory
pathroc = "/cw3e/mead/projects/cwp130/scratch/cgrudzien/rocoto-1.3.3"

##################################################################################
# rocoto utility commands

def run_rocotorun():
    run_cmd = pathroc + "/bin/rocotorun -w " +\
              pathnam + "/" + wrknam + ".xml" +\
              " -d " + outnam + "/workflow/" + wrknam + ".store -v 10"  

    os.system(run_cmd)

def run_rocotoboot(cycle, task_list):
    boot_cmd = pathroc + "/bin/rocotoboot -w " +\
               pathnam + "/" + wrknam + ".xml" +\
               " -d " + outnam + "/workflow/" + wrknam + ".store" +\
               " -c " + cycle + " -t " + task_list

    os.system(boot_cmd) 

def run_rocotostat():
    stat_cmd = pathroc + "/bin/rocotostat -w " +\
               pathnam + "/" + wrknam + ".xml" +\
               " -d " + outnam + "/workflow/" + wrknam + ".store -c all"
    os.system(stat_cmd) 
