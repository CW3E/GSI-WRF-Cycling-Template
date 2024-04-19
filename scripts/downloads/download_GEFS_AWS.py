##################################################################################
# Description
##################################################################################
# This script is to automate downloading GEFS perturbation data for WRF
# initialization over arbitrary date ranges hosted by AWS, without using a
# sign-in to an account.  This data is hosted on the AWS open data service
# sponsored by NOAA at
#
#     https://registry.opendata.aws/noaa-gefs/
#
# Dates are specified in iso format in the global parameters for the script below.
# Other options specify the frequency of forecast outputs, time between zero hours
# and the max forecast hour for any zero hour.
#
# NOTE: as of 2022-10-15 AWS api changes across date ranges, syntax switches
# for dates between:
#
#     2017-01-01 to 2018-07-26
#     2018-07-27 to 2020-09-22
#     2020-09-23 to PRESENT
#
# the exclude statements in the below are designed to handle these exceptions
# using a recurisive copy from a base path.
# 
##################################################################################
# License Statement:
##################################################################################
# This software is Copyright © 2024 The Regents of the University of California.
# All Rights Reserved. Permission to copy, modify, and distribute this software
# and its documentation for educational, research and non-profit purposes,
# without fee, and without a written agreement is hereby granted, provided that
# the above copyright notice, this paragraph and the following three paragraphs
# appear in all copies. Permission to make commercial use of this software may
# be obtained by contacting:
#
#     Office of Innovation and Commercialization
#     9500 Gilman Drive, Mail Code 0910
#     University of California
#     La Jolla, CA 92093-0910
#     innovation@ucsd.edu
#
# This software program and documentation are copyrighted by The Regents of the
# University of California. The software program and documentation are supplied
# "as is", without any accompanying services from The Regents. The Regents does
# not warrant that the operation of the program will be uninterrupted or
# error-free. The end-user understands that the program was developed for
# research purposes and is advised not to rely exclusively on the program for
# any reason.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
# EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE. THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED
# HEREUNDER IS ON AN “AS IS” BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO
# OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
# 
##################################################################################
# Imports
##################################################################################
import os, sys, ssl
import calendar
import glob
from datetime import datetime as dt
from datetime import timedelta
from download_utilities import STR_INDT, get_reqs

##################################################################################
# SET GLOBAL PARAMETERS 
##################################################################################
# starting date and zero hour of data
START_DATE = '2022-12-23T00:00:00'

# final date and zero hour of data
END_DATE = '2022-12-27T00:00:00'

# interval of forecast data outputs after zero hour
FCST_INT = 3

# number of hours between zero hours for forecast data
CYCLE_INT = 24

# max forecast length in hours
MAX_FCST = 120

# root directory where date stamped sub-directories will collect data downloads
DATA_ROOT = '/expanse/lustre/projects/ddp181/cgrudzien/JEDI-MPAS-Common-Case/DATA/GEFS'

##################################################################################
# UTILITY METHODS
##################################################################################

CMD = 'aws s3 cp --no-sign-request s3://noaa-gefs-pds/gefs.'

##################################################################################
# Download data
##################################################################################
# define date range to get data
start_date = dt.fromisoformat(START_DATE)
end_date = dt.fromisoformat(END_DATE)

# obtain combinations
date_reqs, fcst_reqs = get_reqs(start_date, end_date, FCST_INT,
                                CYCLE_INT, MAX_FCST)

# make requests
for date in date_reqs:
    print('Downloading GEFS Date ' + date.strftime('%Y-%m-%d') + '\n')
    print('Zero Hour ' + date.strftime('%H') + '\n')

    down_dir = DATA_ROOT + '/' + date.strftime('%Y%m%d') + '/'
    os.system('mkdir -p ' + down_dir)

    for fcst in fcst_reqs:
        # the following are the two and three digit padding versions of the hours
        HH  = fcst.zfill(2)
        HHH = fcst.zfill(3)
        print(STR_INDT + 'Forecast Hour ' + HH + '\n')
        cmd = CMD + date.strftime('%Y%m%d') + '/' + date.strftime('%H') + ' ' +\
              down_dir + ' ' +\
              '--recursive ' +\
              '--exclude \'*\'' + ' ' +\
              '--include \'*f' + HH + '\' '  +\
              '--include \'*f' + HHH + '\' '  +\
              '--exclude \'*chem*\'' + ' ' +\
              '--exclude \'*wave*\'' + ' ' +\
              '--exclude \'*geavg*\'' + ' ' +\
              '--exclude \'*gespr*\'' + ' ' +\
              '--exclude \'*0p25*\''

        print(STR_INDT * 2 + 'Running command:\n')
        print(STR_INDT * 3 + cmd + '\n')
        os.system(cmd)

    # unpack data from nested directory structure, excluding the root
    print(STR_INDT + 'Unpacking files from nested directories')
    find_cmd = 'find ' + down_dir + ' -type f > file_list.txt'

    print(find_cmd)
    os.system(find_cmd)
              
    f = open('./file_list.txt', 'r')

    print(STR_INDT * 2 + 'Unpacking nested directory structure into ' + down_dir)
    for line in f:
        cmd = 'mv ' + line[:-1] + ' ' + down_dir
        os.system(cmd)

    # cleanup empty directories and file list
    f.close()

    find_cmd = 'find ' + down_dir + ' -type d > dir_list.txt'
    print(find_cmd)
    os.system(find_cmd)

    f = open('./dir_list.txt', 'r')
    print(STR_INDT * 2 + 'Removing empty nested directories')
    line_list = f.readlines()
    line_list = line_list[-1:0:-1]

    for line in line_list:
        os.system('rmdir ' + line)

    os.system('rm file_list.txt')
    os.system('rm dir_list.txt')

print('\n')
print('Script complete -- verify the downloads at root ' + DATA_ROOT + '\n')

##################################################################################
# end
