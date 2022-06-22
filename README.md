# GSI-WRF-Cycling-Template

## Description
This is a template for running GSI-WRF in an offline cycling experiment with the
[Rocoto workflow manager](https://github.com/christopherwharrop/rocoto) and Slurm.
This repository is designed to run a simple cycling experiment as in the
[GSI tutorial](https://dtcenter.ucar.edu/com-GSI/users/tutorial/online_tutorial/index_v3.7.php)
with the data dependencies for these test cases available there.

This workflow based on the work of Christopher Harrop, Daniel Steinhoff, Matthew Simpson,
Caroline Papadopoulos, Patrick Mulrooney, et al.  Scripts in this repository were
forked and re-written from examples for WRF ensemble forecasting written by the above
authors.  Variable conventions in this version differ from past versions in order
to smooth the differences between WRF and GSI driver scripts.

Perl wrapper scripts were re-written into Python for preference and potential consolidation.

## Getting started
This is an initial commit and it is not intended for others to use until further refactoring
is completed.  In principle, this can automate the GSI tutorial case 6, but there are likely
going to be breaking changes in future commits.  Potential users are advised to work with
this software with this inherent risk.
