#!/bin/sh

set -e

src_dataset="rpool" # local zpool to backup
dst_dataset="zroot/backup" # local or remote destination zpool
dst_ssh="ssh -c arcfour zfsbackup@userver sudo" # arcfour is faster
pipeline="mbuffer -q -v 0 -s 128k -m 1024k | pv"

if [ -z "$pipeline" ]; then
  pipeline="cat -"
fi

if [ -n "$dst_ssh" ]; then
  (zfs list -t snapshot; $dst_ssh zfs list -t snapshot) | ./zfs-incremental.pl "$src_dataset" "$dst_dataset" | sh -ex | sh -ex -c "$pipeline" | $dst_ssh zfs recv -F "$dst_dataset"
else
  zfs list -t snapshot | ./zfs-incremental.pl "$src_dataset" "$dst_dataset" | sh -ex | sh -ex -c "$pipeline" | zfs recv "$dst_dataset"
fi
