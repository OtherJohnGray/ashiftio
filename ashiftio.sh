#!/bin/bash

# ashift values to test
ashifts=( 9 12 13 14 15 16 )


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
ashift_count=${#ashifts[@]}
((test_count=$ashift_count*3))
((runtime=ashift_count*$seconds/60))
echo ""
echo ""
echo "Each fio test will run for $seconds seconds. The $test_count tests will run for approximately $runtime minutes in total. If this is too long, stop this test and use the -s flag to set a lower number of seconds for each fio test."
echo ""
echo ""
echo "starting tests...."

# set up variables
cwd=$(pwd)
commands=(
  "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=4k --size=4g --numjobs=1 --iodepth=1 --runtime=$seconds --time_based --end_fsync=1"
  "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=64k --size=256m --numjobs=16 --iodepth=16 --runtime=$seconds --time_based --end_fsync=1"
  "fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=1m --size=16g --numjobs=1 --iodepth=1 --runtime=$seconds --time_based --end_fsync=1"
)
recordsizes=( 4K 64K 1M )
declare -a results

# run tests
for i in "${ashifts[@]}"
do
  echo "creating testpool with ashift of $i"
	zpool create -o ashift=$i -O acltype=posixacl -O compression=lz4 -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa -O mountpoint=none testpool $disk || exit 1
  for j in {0..2}
  do
    recordsize=${recordsizes[j]}
    command=${commands[j]}
    echo "creating dataset with recordsize of $recordsize"
    zfs create -o recordsize=$recordsize -o mountpoint=/testpool/$recordsize testpool/$recordsize || exit 1
    echo "changing to dataset directory"
    cd /testpool/$recordsize
    echo "running fio command for $seconds seconds: $command"
    if [[ $verbose -eq 1 ]] ; then
      res=$(eval "$command | tee /dev/tty /tmp/ashiftstat.txt | tail -1 || exit 1")
    else
      res=$(eval "$command | tail -1 || exit 1")
    fi
    pat='WRITE: bw=([0-9.]*)MiB/s'
    if [[ "$res" =~ $pat ]]; then
      echo "result was $res"
      echo "match was ${BASH_REMATCH[1]}"
      results+=( ${BASH_REMATCH[1]} )
    else
      echo ""
      echo "ERROR:"
      echo "Could not match output pattern of $pat"
      echo "Is fio reporting bw= in something other than MiB/s ?"
      echo "fio output was: $res"
      exit 1
    fi
    echo "changing back to original working directory"
    cd $cwd
    echo "destroying $recordsize recordsize dataset"
    zfs destroy testpool/$recordsize
  done
  zpool destroy testpool || exit 1
  echo "test zpool destroyed."
done

# print results
((underscore_count=${#disk}+50))
eval printf %.0s- '{1..'"$underscore_count"\}
printf "\n\n\n\n\nWrite performance in MiB/s at various ashifts for $disk\n"
eval printf %.0s- '{1..'"$underscore_count"\}
printf "\n\n"
printf "%6s %10s %10s %10s \n" "ASHIFT" ${recordsizes[0]} ${recordsizes[1]} ${recordsizes[2]}
printf %.0s= {1..39}
((endindex=$ashift_count-1))
for i in $(seq 0 $endindex)
do
  echo 
  ((first=$i*3))
  ((second=$first+1))
  ((third=$second+1))
  printf "%6d %10.0f %10.0f %10.0f \n" ${ashifts[$i]} ${results[$first]} ${results[$second]} ${results[$third]}
done
printf "\n\n\n"


