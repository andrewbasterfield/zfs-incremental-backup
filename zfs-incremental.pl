#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
my $debug = 1;

use constant {
  INCREMENTAL => 0,
  COMPLETE    => 1,
};

my $src_dataset = $ARGV[0];
my $dst_dataset = $ARGV[1];
my $prefix      = $ARGV[2] || '';

$prefix .= "-" if ($prefix);

unless ($src_dataset && $dst_dataset) {
  print STDERR "Usage: $0 <src zfs> <dest zfs> [optional snapshot prefix]\n";
  exit 1;
}

if ($src_dataset eq $dst_dataset) {
  print STDERR "Src dataset and dest dataset cannot have the same name\n";
}

#
# Match pairs of snapshots
#
my $snaps = {};
while (my $line = <STDIN>) {
  if ($line =~ m/^$src_dataset(\/+.*)?([@#])($prefix[0-9]{14})/) {
    my $dataset = $1 || '';
    print STDERR "src: $dataset $3\n" if $debug;
    $snaps->{$dataset}->{$3}->{'src'} = ($2 eq '@' ? 'snapshot' : 'bookmark');
  }

  if ($line =~ m/^$dst_dataset(\/+.*)?@($prefix[0-9]{14})/) {
    my $dataset = $1 || '';
    print STDERR "dst: $dataset $2\n" if $debug;
    $snaps->{$dataset}->{$2}->{'dst'} = 1;
  }
}

print STDERR "SNAPSHOTS\n" if $debug;
print STDERR Dumper($snaps) if $debug;

#
# Find the latest snap that is on both
#
my $candidate_snaps = {};
foreach my $dataset (sort keys %$snaps) {
  foreach my $snap (sort keys %{$snaps->{$dataset}}) {
    $candidate_snaps->{$snap} = INCREMENTAL;
  }
}

print STDERR "CANDIDATE SNAPS #1\n" if $debug;
print STDERR Dumper($candidate_snaps) if $debug;

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
        $candidate_snaps->{$snap} = COMPLETE;
      } else {
        print STDERR "$snap is not present on destination of $dataset, discounting\n" if $debug;
        delete $candidate_snaps->{$snap};
      }
    }
    if ($snaps->{$dataset}->{$snap}->{'src'}) {
      push @deletion_list, "$src_dataset$dataset\@$snap" if $snaps->{$dataset}->{$snap}->{'src'} eq "snapshot";
      push @deletion_list, "$src_dataset$dataset\#$snap" if $snaps->{$dataset}->{$snap}->{'src'} eq "bookmark";
    }
  }
}

print STDERR "CANDIDATE SNAPS #2\n" if $debug;
print STDERR Dumper($candidate_snaps) if $debug;

my @candidate_list = sort keys %$candidate_snaps;

my $start_snap = pop @candidate_list;

print STDERR "Found starting snapshot $start_snap\n" if $start_snap && $debug;

#
# Create a snapshot name
#
my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst ) = localtime(time());
my $now = sprintf("%04d%02d%02d%02d%02d%02d",1900+$year,1+$month,$day,$hour,$min,$sec);

my $end_snap = $src_dataset.'@'.$prefix.$now;
print "zfs snapshot -r $end_snap\n";

if (0) {
  my $end_bookmark = $end_snap;
  $end_bookmark =~ s/\@/#/;
  
  foreach my $dataset (keys %$snaps) {
    print "zfs bookmark ".$src_dataset.$dataset.'@'.$prefix.$now." ".$src_dataset.$dataset.'#'.$prefix.$now."\n";
  }
  
  print "zfs destroy $end_snap\n";
  $end_snap = $end_bookmark;
}

#
# -q quiet
# -v verbosity zero
# -s blocksize
# -m total buffer size
#
print STDERR Dumper($snaps);
print "zfs send -R ".(defined $start_snap && $candidate_snaps->{$start_snap} == INCREMENTAL ? "-i $src_dataset". ( $snaps->{''}->{$start_snap}->{'src'} eq 'bookmark' ? '#' : '@' )  ."$start_snap" : "")." $end_snap\n";

foreach my $snap (@deletion_list) {
  print "zfs destroy $snap\n";
}
