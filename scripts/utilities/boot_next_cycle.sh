#!/bin/bash
##################################################################################
# Description
##################################################################################
# This utility script is designed to force Rocoto to run complex workflows that
# fail when cycles refuse to trigger.  This was generated by testing and modifying
# the Rocoto source such that the file located from the clone root:
#
# rocoto/lib/workflowmgr/workflowengine.rb
# 
# in line 408 is edited to read:
#
# reply='y'
#
# thereby removing the interactive prompt.  This allows one to rocoto boot the
# next cycle first task by grepping the rocoto workflow logs and prompting the
# cycle to run using a dummy task "boot_next_cycle" which can be trigged based on
# arbitrary conditions within the current cycle.  This is a very hacky solution and
# will be made obsolete when the system is fully re-written for using Cylc to
# improve performance, long-term support and overall reliability.
#
##################################################################################
# License Statement:
##################################################################################
# Copyright 2023 Colin Grudzien, cgrudzien@ucsd.edu
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

if [ ! ${CLNE_ROOT} ]; then 
  echo "ERROR: clone root \${CLNE_ROOT} is not defined."
  exit 1
fi

if [ ! ${CYC} ]; then
  echo "ERROR: next cycle date time \${CYC} is not defined."
  exit 1
fi

if [ ! ${CSE} ]; then
  echo "ERROR: case study \${CSE} is not defined."
  exit 1
fi

if [ ! ${FLW} ]; then
  echo "ERROR: control flow \${FLW} is not defined."
  exit 1
fi

# define the workflow log
worklog=${CLNE_ROOT}/workflow_status/${CSE}-${FLW}_workflow_status.txt 

# check the number of lines
linecount=`wc -l < ${worklog}`

if [ ! -r ${worklog} ]; then
  echo "ERROR: worfklow log ${worklog} does not exist or is not readable."
  exit 1
elif [ ${linecount} -eq 0 ]; then
  echo "ERROR: workflow log ${worklog} is empty."
  exit 1
else
  # grep the next task from the workflow status log
  IFS=" " read -ra cyc_stat <<< `grep "${CYC}" ${worklog} | head -n 1`
fi

# unpack next task to boot from the status log
tsk=${cyc_stat[1]}

cmd="cd ${CLNE_ROOT}"
echo ${cmd}; eval ${cmd}

cmd="python -c 'import rocoto_utilities; rocoto_utilities.run_rocotoboot([\"${CSE}\"],[\"${FLW}\"],[\"${CYC}\"],[\"${tsk}\"])'"
echo ${cmd}; eval ${cmd}

cmd="sleep 300"
echo ${cmd}; eval ${cmd}

# check for an update to the workflow log with new status for job
if [ ! -r ${worklog} ]; then
  echo "ERROR: worfklow log ${worklog} does not exist or is not readable."
  exit 1
elif [ ${linecount} -eq 0 ]; then
  echo "ERROR: workflow log ${worklog} is empty."
  exit 1
else
  IFS=" " read -ra cyc_stat <<< `grep "${CYC}" ${worklog} | head -n 1`
fi

# define a regular expression to match integer patterns to check for job id
re='^[0-9]+$'

# unpack grepped line
cycle=${cyc_stat[0]}
task=${cyc_stat[1]}
job_id=${cyc_stat[2]}

if ! [[ ${job_id} =~ ${re} ]]; then
  echo "ERROR: task did not update."
  exit 1
else
  echo "Task ${task} booted for cycle ${cycle} with job id:"
  echo "${job_id}"
fi

echo "Script completed at `date +%Y-%m-%d_%H_%M_%S`."
exit 0
