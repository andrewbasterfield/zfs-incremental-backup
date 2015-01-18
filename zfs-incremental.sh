#!/bin/sh

set -e

src_dataset="rpool"
dst_dataset="zroot/backup"
dst_user="backup@userver"


if [ -n "$dst_user" ]; then
  dst_ssh="ssh -c arcfour zfsbackup@userver sudo"
fi

#zfs list -t snapshot | ./zfs-incremental.pl "$src_dataset" "$dst_dataset" | sh -e -x | mbuffer -q -v 0 -s 128k -m 1024k | zfs recv "$dst_dataset"

if [ -n "$dst_user" ]; then
  dst_ssh="ssh -c arcfour zfsbackup@userver sudo"
fi

(zfs list -t snapshot; $dst_ssh zfs list -t snapshot) | ./zfs-incremental.pl "$src_dataset" "$dst_dataset" | sh -e -x | mbuffer -q -v 0 -s 128k -m 1024k | pv | $dst_ssh zfs recv -F "$dst_dataset"
