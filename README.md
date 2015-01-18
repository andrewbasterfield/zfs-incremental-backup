# zfs-incremental-backup
Scripts for performing ZFS incremental backup (using ZFS send/recv) optionally over SSH

The perl script zfs-incremental.pl contains the (hopefully fairly generic) logic to determine the incremental start
snapshot (if applicable), create a current snapshot and hence generate the shell commands to perform the incremental
or full backup.

The snapshots are expected in the format date +%Y%m%d%H%M%S e.g. 20150118224238; pre-existing snapshots not in this
format are ignored. The script chooses the 'start' snapshot based on the latest snapshot present in both the start
and destination ZFS data-sets. The 'end' snapshot is generated at the execution time of the script.

At the end of execution of the script unecessary source snapshots are destroyed.
