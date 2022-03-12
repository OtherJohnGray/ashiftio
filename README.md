# ashiftio
Bash script to test different ZFS ashifts on a drive and report relative performance, to assist in choosing the ideal ashift for your device. Requires fio and bc.

PLEASE NOTE THAT THIS IS A DESTRUCTIVE TEST INTENDED TO BE PERFORMED ON A BLANK DRIVE OR PARTITION - DO NOT RUN THIS ON A BLOCK DEVICE WITH DATA YOU WISH TO KEEP!

Installation:

1. Make sure that ZFS, fio, and bc are installed on your system.
2. Identify the path to the block device you wish to test under /dev, e.g. something like (Linux) /dev/disk/by-id/nvme-KINGSTON_SKC2500M8500G_****** or (BSD) /dev/ada0
3. git clone https://github.com/OtherJohnGray/ashiftio.git
4. cd ashiftio
5. ./ashiftio <path to block device from #2 above>

Usage: 

ashiftio [-v][-s seconds] path-to-block-device

Optional flags:

-v          Verbose - show all fio output
-s seconds  Number of seconds each fio test should run for (default 60). There are 54 tests in total


Ashiftio accepts the path to a block device as a parameter. It creates zpools with ashift of 9, 12, and 13 in turn, and then creates datasets with record size of 4K, 8K, 16K, 64K, 128K, and 1M. On each dataset, it runs 
three fio tests to simulate different workloads. Based on the recommendations from https://arstechnica.com/gadgets/2020/02/how-fast-are-your-disks-find-out-the-open-source-way-with-fio/ the workloads are Single 4KiB random write process, 
16 parallel 64KiB random write processes, and Single 1MiB random write process. It then displays the results of each workload in tabular form by recordsize and ashift.

If you would like to change the recordsize or ashifts used, you can easily edit the values at the top of the script.



