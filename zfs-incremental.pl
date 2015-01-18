#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
my $debug = 1;

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
  if ($line =~ m/^$src_dataset(\/+.*)?@([0-9]{14})/) {
    my $dataset = $1 || '';
    print STDERR "src: $dataset $2\n" if $debug;
    $snaps->{$dataset}->{$2}->{'src'} = 1;
  }

  if ($line =~ m/^$dst_dataset(\/+.*)?@([0-9]{14})/) {
    my $dataset = $1 || '';
    print STDERR "dst: $dataset $2\n" if $debug;
    $snaps->{$dataset}->{$2}->{'dst'} = 1;
  }
}

print STDERR Dumper($snaps) if $debug;

#
# Find the latest snap that is on both
#
my $candidate_snaps = {};
foreach my $dataset (sort keys %$snaps) {
  foreach my $snap (sort keys %{$snaps->{$dataset}}) {
    $candidate_snaps->{$snap} = undef;
  }
}

my @deletion_list;
foreach my $dataset (sort keys %$snaps) {
  foreach my $snap (sort keys %{$snaps->{$dataset}}) {
    if (exists $candidate_snaps->{$snap}) {
      print STDERR "Verifying $snap\n" if $debug;
      if ($snaps->{$dataset}->{$snap}->{'src'} && $snaps->{$dataset}->{$snap}->{'dst'}) {
        print STDERR "snapshot $snap is present on both source and destination datasets $dataset\n" if $debug;
      } elsif (exists $snaps->{$dataset}->{$snap}->{'dst'}) {
        print STDERR "$snap is not present on destination dataset $dataset, extended check to see if there are ANY snaps on src dataset\n" if $debug;
        #
        # If we have a candidate snapshot on the destination but there are no snapshots at all on the source that candidate snapshot is OK
        #
        foreach my $asnap (sort keys %{$snaps->{$dataset}}) {
          if (exists $snaps->{$dataset}->{$asnap}->{'src'}) {
            print STDERR "source dataset $dataset has snapshot $asnap, discounting snapshot $snap\n" if $debug;
            delete $candidate_snaps->{$snap};
            last;
          }
        }
        print STDERR "snapshot $snap still acceptable; no snaps on src\n" if exists $candidate_snaps->{$snap} and $debug;
      } else {
        print STDERR "$snap is not present on destination of $dataset, discounting\n" if $debug;
        delete $candidate_snaps->{$snap};
      }
    }
    push @deletion_list, "$src_dataset$dataset\@$snap" if $snaps->{$dataset}->{$snap}->{'src'};
  }
}

print STDERR Dumper($candidate_snaps) if $debug;

my @candidate_list = sort keys %$candidate_snaps;

my $start_snap = pop @candidate_list;

print STDERR "Found starting snapshot $start_snap\n" if $start_snap && $debug;

#
# Create a snapshot name
#
my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst ) = localtime(time());
my $now = sprintf("%04d%02d%02d%02d%02d%02d",1900+$year,1+$month,$day,$hour,$min,$sec);

my $end_snap = $src_dataset.'@'.$now;

#print "\n";
print "zfs snapshot -r $end_snap\n";
#
# -q quiet
# -v verbosity zero
# -s blocksize
# -m total buffer size
#
print "zfs send -R ".(defined $start_snap ? "-i $start_snap" : "")." $end_snap\n";

foreach my $snap (@deletion_list) {
  print "zfs destroy $snap\n";
}
