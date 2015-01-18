#!/bin/sh

set -e

zfs list -t snapshot | ./zfs-incremental.pl rpool backup/rpool | sh -e -x
