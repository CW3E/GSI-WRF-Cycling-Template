#/bin/sh

# SET UP VALID TIME
sd=2021-12-29
tt=00
      
export VALIDYEAR=${sd:0:4}
export VALIDMON=${sd:5:2}
export VALIDDAY=${sd:8:2}
export VALIDHR=$tt

# SET UP DIRECTORIES OF INPUT/OUTPUT/OBSERVATIONS

# change as a function of lead time, just 1-day lead time for now
lt=1
INITDAY=`expr $VALIDDAY - $lt`
wrf_cf_output="/cw3e/mead/datasets/cw3e/NRT/2021-2022/NRT_gfs/${VALIDYEAR}${VALIDMON}${INITDAY}${VALIDHR}/cf/" 


# set up other access directories           
wrf_met_output_root="/cw3e/mead/projects/cwp129/cw3e_MET_verification/MET_output/NRT_gfs/${VALIDYEAR}${VALIDMON}${VALIDDAY}${VALIDHR}/"
stage_iv_root="/cw3e/mead/projects/cnt102/METMODE_PreProcessing/data/StageIV/"
scripts_home="/cw3e/mead/projects/cwp129/cw3e_MET_verification/driver_scripts/"
mask_polygon_root="/cw3e/mead/projects/cwp129/cw3e_MET_verification/common_polygons/region/"

## MET Singularity Path
#metsrc="/cw3e/mead/projects/cwp110/cpapadop/ENSEMBLE_test_2/post_proc/apps/metmode/8.0/metmode-8.0.sif"
metsrc="/cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif"

#check if directory exists, if not than make it
if [ ! -d $wrf_met_output_root ] 
then
   echo "Directory $wrf_met_output_root DOES NOT exist.  Creating it now." 
   mkdir -p $wrf_met_output_root
fi

# Set up singularity container
# log singularity setup line
#singularity instance start -B  /cw3e/mead/projects/cwp110/cpapadop/ENSEMBLE_test_2/output/cf_compliant:/input:ro,/cw3e/mead/projects/cnt102/MET/testing_ensemble_output/phase2_verify:/
#output:rw,/cw3e/mead/projects/cwp110/Forcing/StageIV:/forcing_stageiv:ro,/cw3e/mead/projects/cwp110/cpapadop/ENSEMBLE_test_2/post_proc/Scripts:/scripts:ro /cw3e/mead/projects/cwp110/
#cpapadop/ENSEMBLE_test_2/post_proc/apps/metmode/8.0/metmode-8.0.sif met1

echo "singularity instance start -B  ${wrf_cf_output}:/input:ro,${wrf_met_output_root}:/output:rw,${stage_iv_root}:/root_stageiv:ro,${scripts_home}:/scripts:ro ${metmode} met1"  
# echo "singularity instance start -B  ${wrf_cf_output}:/input:ro,${wrf_met_output_root}:/output:rw,${stage_iv_root:/root_stageiv:ro,${scripts_home}:/scripts:ro ${metmode} met1" >> $log_file 

singularity instance start -B ${wrf_cf_output}:/input:ro,${wrf_met_output_root}:/output:rw,${stage_iv_root}:/root_stageiv:ro,${mask_polygon_root}:/root_mask:ro,${scripts_home}:/scripts:ro ${metsrc} met1 


## Combine 3-hr precip to 24-hr
statement="singularity exec instance://met1 pcp_combine \
-sum 00000000_000000 1 ${VALIDYEAR}${VALIDMON}${VALIDDAY}_${VALIDHR}0000 24 \
/output/test_NRT_pcpcombine_${VALIDYEAR}${VALIDMON}${VALIDDAY}${VALIDHR}_24A.nc \
-field 'name=\"precip_bkt\";  level=\"(*,*,*)\";' -name \"24hr_qpf\" \
-pcpdir /input \
-pcprx \"wrfcf_gfs_d02_\" \
-v 1"
echo $statement
eval $statement

## Regrid to Stage-IV
statement="singularity exec instance://met1 regrid_data_plane \
/output/test_NRT_pcpcombine_${VALIDYEAR}${VALIDMON}${VALIDDAY}${VALIDHR}_24A.nc \
/root_stageiv/StageIV_QPE_${VALIDYEAR}${VALIDMON}${VALIDDAY}${VALIDHR}.nc \
/output/regridded_NRT_pcpcombine_${VALIDYEAR}${VALIDMON}${VALIDDAY}${VALIDHR}_24A.nc -field 'name=\"24hr_qpf\";  level=\"(*,*)\";'  -method BILIN -width 2 -v 1"
echo $statement
eval $statement

## Create mask for Russian River watershed - note, do not need to run this each time, should set up StageIV specific path
statement="singularity exec instance://met1 gen_vx_mask -v 10 \
/output/regridded_NRT_pcpcombine_${VALIDYEAR}${VALIDMON}${VALIDDAY}${VALIDHR}_24A.nc \
-type poly \
/root_mask/Russian_LatLonPoints.txt \
/output/Russian_mask_regridded_NRT_pcpcombine_with_StageIV.nc"
echo $statement
eval $statement


## RUN GRIDSTAT
statement="singularity exec instance://met1 grid_stat -v 10 \
/output/regridded_NRT_pcpcombine_${VALIDYEAR}${VALIDMON}${VALIDDAY}${VALIDHR}_24A.nc
/root_stageiv/StageIV_QPE_${VALIDYEAR}${VALIDMON}${VALIDDAY}${VALIDHR}.nc \
/scripts/GridStatConfig
-outdir /output"
echo $statement
eval $statement






# End MET Process and singularity stop
singularity instance stop met1








# Archive Notes

#singularity exec /cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif ls /usr/local/bin
#singularity exec -B /cw3e/mead/projects/cwp129/weihsr/scratch/:/input:ro /cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif pcp_combine -sum 00000000_000000 1 20211229_000000 3 /output\test_NRT_pcpcombine_20211229_24A.nc -field 'name="precip";  level="(*,*,*)";' -name "24hr_qpf" -pcpdir /input -pcprx "wrfcf_gfs_d02_" 
#singularity exec -B /cw3e/mead/datasets/cw3e/NRT/2021-2022/NRT_gfs/2021122800/cf/:/input:ro /cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif ls /input

## Get default config file from src
#singularity exec -B /cw3e/mead/projects/cwp129/cw3e_MET_verification/driver_scripts:/scripts:rw /cw3e/mead/projects/cwp129/Software/MET/Met/met-10.0.1/met-10.0.1.sif cp /usr/local/share/met/config/GridStatConfig_default /scripts

#singularity exec instance://met1 pcp_combine -sum 00000000_000000 1 20211229_000000 24 test_NRT_pcpcombine_20211229_24A.nc -field 'name="precip";  level="(L0,*,*)";' -name "24hr_qpf"









