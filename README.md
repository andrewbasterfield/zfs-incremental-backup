# zfs-incremental-backup Scripts for performing ZFS incremental backup
(using ZFS send/recv) optionally over SSH

The perl script zfs-incremental.pl contains the (hopefully fairly generic)
logic to determine the latest common start snapshot (if possible) for
incremental backup shared between source and destination data-sets, create a
new source snapshot to delineate the end of the backup and hence generate
(print to standard output) the shell commands to perform the incremental or
full backup.

The snapshots are created and expected in the format date +%Y%m%d%H%M%S e.g. 
20150118224238; pre-existing snapshots not in this format are ignored.  The
script chooses the 'start' snapshot based on the latest snapshot present in
both the start and destination ZFS data-sets.  The 'end' snapshot is
generated at the execution time of the script.

The shell script zfs-incremental.sh wraps the perl script with
application-specific arguments to make it work; it reads the output of the
perl script and pipes it into a shell to do the work.

At the end of execution of the script unecessary source snapshots are
destroyed.
