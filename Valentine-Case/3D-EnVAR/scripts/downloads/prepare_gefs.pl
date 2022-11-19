#!/usr/bin/perl -w
use strict;

#### USER SPECIFICATIONS ####
my $path = $ENV{'SOURCE_PATH'};
my $forcing = $ENV{'SOURCE_FORCING_PATH'};
my $cd = $ENV{'CYCLE_DATE'};
my $puser = $ENV{'PIPELINE_USERID'};
#### END USER SPECIFICATIONS ####

#### VARIABLE DECLARATIONS ####

# Scalars
# Arrays
# Hashes

system "mkdir -p $path/$cd";
if (-e "$path/${cd}_raw") {
    system("/bin/rm $path/${cd}_raw ");
}
#cpapadop NOTE: forcing now on comet so don't have to copy just link
system ("ln -s $forcing/${cd}_raw $path/${cd}_raw") and die ("ln forcing died: $!");
#system "mkdir -p $path/${cd}_raw";
#
for (my $i = 0; $i < 21; $i++)
{
    my $sdir = sprintf("%02d", $i);
    system "mkdir -p $path/$cd/gefs$sdir";
}
my $cd1 = substr($cd, 0, 8);
my $cd2 = substr($cd, 8, 2);
my $cycle_date = "$cd1 $cd2";
my $year = substr($cd, 0, 4);
my $mon = substr($cd, 4, 2);
my $day = substr($cd, 6, 2);
my $hour = substr($cd, 8, 2);
my $grib_copy = "/home/steinhof/apps/bin/grib_copy";
#system ("export LD_LIBRARY_PATH=/home/steinhof/apps/ECCODES-2.13.1/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}");


#cpapadop NOTE: forcing now on comet so don't have to copy just link
#system ("scp -r -i /home/cpapadop/.ssh/id_rsa_wrf $puser\@pipeline.ucsd.edu:/zdata/cw3e-temp/GEFS_ensemble/gefs_pf_pl_${year}-${mon}-${day}_${hour}.grb cpapadop\@pipeline.ucsd.edu:/zdata/cw3e-temp/GEFS_ensemble/gefs_pf_sfc_${year}-${mon}-${day}_${hour}.grb $path/${cd}_raw") and die ("SCP failed: $!");

chdir "$path/${cd}_raw";
my @files = glob "gefs*.grb";
foreach my $file (@files)
{
    print "$file\n";
    my @parts = split /_/, $file;
    my $hr = substr ($parts[3], 0, 2);
    system ("$grib_copy $file \'$path/$cd/$parts[0]_$parts[1]_$parts[2]_${hr}_[shortName]_[perturbationNumber]_[forecastTime].grib\'") and die ("$grib_copy failed: $!");
}

chdir "$path/$cd";
@files = glob "*.grib";
foreach my $file (@files)
{
    my @parts = split /_/, $file;
    my $pert = sprintf("%02d", $parts[5]);
    system "mv $file gefs$pert";
}
