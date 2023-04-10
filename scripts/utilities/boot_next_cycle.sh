#!/bin/bash

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

# grep the next task from the workflow status log
IFS=" " read -ra cyc_stat <<< `grep "${CYC}" ${CLNE_ROOT}/workflow_status/${CSE}-${FLW}_workflow_status.txt | head -n 1`

# unpack next task to boot from the status log
tsk=${cyc_stat[1]}

cmd="cd ${CLNE_ROOT}"
echo ${cmd}; eval ${cmd}

cmd="python -c 'import rocoto_utilities; rocoto_utilities.run_rocotoboot([\"${CSE}\"],[\"${FLW}\"],[\"${CYC}\"],[\"${tsk}\"]) Y'"
echo ${cmd}; eval ${cmd}

exit 0
