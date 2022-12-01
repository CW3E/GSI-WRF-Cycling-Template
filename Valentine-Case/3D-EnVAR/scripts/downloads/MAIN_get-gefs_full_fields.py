#!/usr/bin/env python

# This script downloads the GEFS ensemble and control members from the ECMWF TIGGE dataset.  
# Code created/modified by Rachel Weihs from autogenerated ECMWF python script 
# Last updated:  September 2, 2020 2pm

#instructions:
# This script can batch the download of GEFS data for f0-f144 hr, 21 members, and loops over several dates.
# To run:
# 1) Edit dates in the "dates" array below (typically 3 work before timeout issues)
# 2) Run script:
#   >> python MAIN_get-gefs_full_fields.py

# This script will produce four types of files containing
#  a) surface perturbed data for members 1-20
#  b) pressure level perturbed data for members 1-20)
#  c) surface control run data
#  d) pressure level control data

#notes:
# At the present, accessing these data are quite slow.  Therefore, I can usually 
# download about 3 dates in one day without failures (usually due to my own connectivity
# or timeout errors, depending on whether requests get queued or active).  
# If others experience more efficient downloads, please let me know.
# This script also contains commands to download other static data, but already have 
# what we need.  

from ecmwfapi import ECMWFDataServer
server = ECMWFDataServer()
    
def retrieve_tigge_data():
#    dates = ['2019-01-26', '2019-01-27', '2019-01-28']
    dates = ['2019-02-06']
    times = ['00']
    for date in dates:
         for time in times:
             target = '/zdata/cw3e-temp/GEFS_ensemble/gefs_pf_sfc_%s_%s.grb' % (date, time)
             tigge_pf_sfc_request(date, time, target)
             target = '/zdata/cw3e-temp/GEFS_ensemble/gefs_pf_pl_%s_%s.grb' % (date, time)
             tigge_pf_pl_request(date, time, target)
             #target = 'gefs_control/gefs_cf_sfc_%s_%s.grb' % (date, time)
             #tigge_cf_sfc_request(date, time, target)
             #target = 'gefs_control/gefs_cf_pl_%s_%s.grb' % (date, time)
             #tigge_cf_pl_request(date, time, target)

 
def tigge_pf_pl_request(date, time, target):
    '''
       A TIGGE request for perturbed forecast, pressure level, ECMWF Center.
       Please note that a subset of the available data is requested below.
       Change the keywords below to adapt it to your needs. (ie to add more parameters, or numbers etc)
    '''
    server.retrieve({
        'class': 'ti',
        'dataset': 'tigge',
        'date': date,
        'expver': 'prod',
        'grid': '0.5/0.5',
        'levelist': '200/250/300/500/700/850/925/1000',
        'levtype': 'pl',
        'number': '1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/17/18/19/20',
        'origin': 'kwbc',
        'param': '130/131/132/133/156',
        'step': '0/6/12/18/24/30/36/42/48/54/60/66/72/78/84/90/96/102/108/114/120/126/132/138/144/150/156/162/168',
        'target': target,
        'time': time,
        'type': 'pf',
    })
 
def tigge_pf_sfc_request(date, time, target):
    '''
       A TIGGE request for perturbed forecast, sfc, ECMWF Center.
       Please note that a subset of the available data is requested below.
       Change the keywords below to adapt it to your needs. (ie to add more parameters, or numbers etc)
    '''
    server.retrieve({
         'class': 'ti',
         'dataset': 'tigge',
         'date': date,
         'expver': 'prod',
         'grid': '0.5/0.5',
         'levtype': 'sfc',
         'number': '1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/17/18/19/20',
         'origin': 'kwbc',
         'param': '134/151/165/166/167/168/235/228039/228139/228144',
         'step': '0/6/12/18/24/30/36/42/48/54/60/66/72/78/84/90/96/102/108/114/120/126/132/138/144/150/156/162/168',
         'target': target,
         'time': '00:00:00',
         'type': 'pf',
       })

def tigge_pf_sfc_static_request(date, time, target):
    '''
       A TIGGE request for perturbed forecast, sfc, ECMWF Center.
       Please note that a subset of the available data is requested below.
       Change the keywords below to adapt it to your needs. (ie to add more parameters, or numbers etc)
    '''
    server.retrieve({
         'class': 'ti',
         'dataset': 'tigge',
         'date': date,
         'expver': 'prod',
         'grid': '0.5/0.5',
         'levtype': 'sfc',
         'number': '1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/17/18/19/20',
         'origin': 'kwbc',
         'param': '228002',
         'step': '0',
         'time': '00:00:00',
         'type': 'pf',
         'target': target,
       })

def tigge_pf_sfc_lndmsk_request(date, time, target):
    '''
       A TIGGE request for perturbed forecast, sfc, ECMWF Center.
       Please note that a subset of the available data is requested below.
       Change the keywords below to adapt it to your needs. (ie to add more parameters, or numbers etc)
    '''
    server.retrieve({
         'class': 'ti',
         'dataset': 'tigge',
         'date': date,
         'expver': 'prod',
         'grid': '0.5/0.5',
         'levtype': 'sfc',
         'number': '1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/17/18/19/20',
         'origin': 'kwbc',
         'param': '172',
         'step': '6',
         'time': '00:00:00',
         'type': 'pf',
         'target': target,
       })

def tigge_cf_pl_request(date, time, target):
    '''
       A TIGGE request for perturbed forecast, pressure level, ECMWF Center.
       Please note that a subset of the available data is requested below.
       Change the keywords below to adapt it to your needs. (ie to add more parameters, or numbers etc)
    '''
    server.retrieve({
        'class': 'ti',
        'dataset': 'tigge',
        'date': date,
        'expver': 'prod',
        'grid': '0.5/0.5',
        'levelist': '200/250/300/500/700/850/925/1000',
        'levtype': 'pl',
        'origin': 'kwbc',
        'param': '130/131/132/133/156',
        'step': '0/6/12/18/24/30/36/42/48/54/60/66/72/78/84/90/96/102/108/114/120/126/132/138/144/150/156/162/168',
        'target': target,
        'time': time,
        'type': 'cf',
    })
 
def tigge_cf_sfc_request(date, time, target):
    '''
       A TIGGE request for perturbed forecast, sfc, ECMWF Center.
       Please note that a subset of the available data is requested below.
       Change the keywords below to adapt it to your needs. (ie to add more parameters, or numbers etc)
    '''
    server.retrieve({
         'class': 'ti',
         'dataset': 'tigge',
         'date': date,
         'expver': 'prod',
         'grid': '0.5/0.5',
         'levtype': 'sfc',
         'origin': 'kwbc',
         'param': '134/151/165/166/167/168/235/228039/228139/228144',
         'step': '0/6/12/18/24/30/36/42/48/54/60/66/72/78/84/90/96/102/108/114/120/126/132/138/144/150/156/162/168',
         'target': target,
         'time': '00:00:00',
         'type': 'cf',
       })
 
if __name__ == '__main__':
    retrieve_tigge_data()
