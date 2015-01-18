These are test cases to verify the operation of the perl code. They contain
the output of 'zfs send -t snapshot' concatenated across source and
destination hosts.

The source and destination ZFS data sets are identifed as 'source' and
'destination'.

Test with e.g.

../zfs-incremental.pl source destination <01_incremental.txt 
