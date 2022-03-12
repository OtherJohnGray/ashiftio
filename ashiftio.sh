#!/bin/bash

usage() {
    echo 'usage: ashiftio [-v][-s seconds] path-to-block-device'
    exit 0
}

if [[ $# -eq 0 ]] ; then
  usage
fi


# get $seconds from optional parameter, default 60
verbose=0
seconds=60
while getopts "vs:" opt; do
    case $opt in
        v) verbose=1 ;;
        s) seconds="${OPTARG}" ;;
    esac
done
shift $(( OPTIND - 1 ))
[[ $seconds =~ ^[0-9]*$ ]] || { echo "invalid seconds parameter of $seconds"; exit 1; }
echo "each fio test will run for $seconds seconds"

# get disk to test
if [[ $# -eq 0 ]] ; then
    echo 'please provide a path to a specific disk, e.g. something like (Linux) /dev/disk/by-id/nvme-KINGSTON_SKC2500M8500G_****** or (BSD) /dev/ada0'
    exit 0
fi
disk=$1

# confirm testing
echo
echo
echo "WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! WARNING! "
echo
read -p "WARNING! This script WILL DESTROY ALL DATA ON $disk - Do you wish to continue? [y|N]  " continue
echo
[[ ${continue,,} =~ ^(y|yes)$ ]] || { echo "exiting..."; exit 1; }

# display runtime
((runtime=54*$seconds/60))
echo ""
echo ""
echo "Each fio test will run for $seconds seconds. The 54 tests will run for approximately $runtime minutes in total. If this is too long, stop this test and use the -s flag to set a lower number of seconds for each fio test."
echo ""
echo ""
echo "starting tests...."

# set up variables
cwd=$(pwd)
ashifts=( 9 12 13 )
recordsizes=(4K 8K 16K 64k 128K 1M)
commands=(
  "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=4k --size=4g --numjobs=1 --iodepth=1 --runtime=$seconds --time_based --end_fsync=1"
  "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=64k --size=256m --numjobs=16 --iodepth=16 --runtime=$seconds --time_based --end_fsync=1"
  "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=1m --size=16g --numjobs=1 --iodepth=1 --runtime=$seconds --time_based --end_fsync=1"
)

# run tests
for i in "${ashifts[@]}"
do
  echo "creating testpool with ashift of $i"
	zpool create -o ashift=$i -O acltype=posixacl -O compression=lz4 -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa -O mountpoint=none testpool $disk || exit 1
  for j in "${recordsizes[@]}"
  do
    echo "creating dataset with recordsize of $j"
    zfs create -o recordsize=$j -o mountpoint=/testpool/$j testpool/$j || exit 1
    echo "changing to dataset directory"
    cd /testpool/$j
    for k in "${commands[@]}"
    do
      echo "running fio command for $seconds seconds:   $k"
      if [[ $verbose -eq 1 ]] ; then
        res=$(eval "$k | tee /dev/tty /tmp/ashiftstat.txt | tail -1 || exit 1")
      else
        res=$(eval "$k | tail -1 || exit 1")
      fi
      pat='WRITE: bw=([0-9.]*)MiB/s'
      if [[ "$res" =~ $pat ]]; then
        echo "result was $res"
        echo "match was ${BASH_REMATCH[1]}"
      else
        echo ""
        echo "ERROR:"
        echo "Could not match output pattern of $pat"
        echo "Is fio reporting bw= in something other than MiB/s ?"
        echo "fio output was: $res"
        exit 1
      fi
    done
    echo "changing back to original working directory"
    cd $cwd
    echo "destroying $j recordsize dataset"
    zfs destroy testpool/$j
  done
  zpool destroy testpool || exit 1
  echo "test zpool destroyed."
done


