#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
my $debug = 1;

#my $src_dataset = "rdataset";
#my $dst_dataset = "backup/rdataset";

my $src_dataset = $ARGV[0];
my $dst_dataset = $ARGV[1];

unless ($src_dataset && $dst_dataset) {
  print "Usage: $0 <src zfs> <dest zfs>\n";
  exit 1;
}

#
# Match pairs of snapshots
#
my $snaps = {};
while (my $line = <STDIN>) {
  if ($line =~ m/^$src_dataset@([0-9]{14})/) {
    print STDERR "src: $1\n" if $debug;
    $snaps->{$1}->{'src'} = 1;
  }

  if ($line =~ m/^$dst_dataset@([0-9]{14})/) {
    print STDERR "dst: $1\n" if $debug;
    $snaps->{$1}->{'dst'} = 1;
  }
}

print STDERR Dumper($snaps) if $debug;

#
# Find the latest snap that is on both
#
my $start_snap;
my @deletion_list;
foreach my $snap (sort keys %$snaps) {
  print STDERR "Verifying $snap\n" if $debug;
  if ($snaps->{$snap}->{'src'} && $snaps->{$snap}->{'dst'}) {
    $start_snap = $snap;
  }
  push @deletion_list, $snap if $snaps->{$snap}->{'src'};
}

print STDERR "Found starting snapshot $start_snap\n" if $start_snap && $debug;

#
# Create a snapshot name
#
my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst ) = localtime(time());
my $now = sprintf("%04d%02d%02d%02d%02d%02d",1900+$year,1+$month,$day,$hour,$min,$sec);

my $end_snap = $src_dataset.'@'.$now;

#print "\n";
print "zfs snapshot -r $end_snap\n";
print "zfs rollback -R $dst_dataset\@$start_snap\n" if defined $start_snap;
#
# -q quiet
# -v verbosity zero
# -s blocksize
# -m total buffer size
#
print "zfs send -R ".(defined $start_snap ? "-i $start_snap" : "")." $end_snap | mbuffer -q -v 0 -s 128k -m 1024k | zfs recv $dst_dataset\n";

foreach my $snap (@deletion_list) {
  print "zfs destroy -R $src_dataset\@$snap\n";
}
