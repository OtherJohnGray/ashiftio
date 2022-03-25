# ashiftio
Bash script to test different ZFS ashifts on a drive and report relative performance, to assist in choosing the ideal ashift for your device. Requires fio.

PLEASE NOTE THAT THIS IS A DESTRUCTIVE TEST INTENDED TO BE PERFORMED ON A BLANK DRIVE OR PARTITION - DO NOT RUN THIS ON A BLOCK DEVICE WITH DATA YOU WISH TO KEEP!

Installation and quickstart:

1. Make sure that ZFS and fio are installed on your system.
2. Identify the path to the block device you wish to test under /dev, e.g. something like (Linux) /dev/disk/by-id/nvme-KINGSTON_SKC2500M8500G_****** or (BSD) /dev/ada0
3. If your device is an NVMe drive, check the blocksize it has been formatted to and reformat it if necessary, according to the instructions at https://openzfs.github.io/openzfs-docs/Performance%20and%20Tuning/Hardware.html#nvme-low-level-formatting
4. git clone https://github.com/OtherJohnGray/ashiftio.git
5. cd ashiftio
6. sudo ./ashiftio <path to block device from #2 above>

Usage: 

ashiftio [-v][-s seconds] path-to-block-device

Optional flags:

-v : Verbose - show all fio output

-s seconds : Number of seconds each fio test should run for (default 60). There are 54 tests in total.


Ashiftio accepts the path to a block device as a parameter. It creates zpools with ashift of 9, 12, 13, 14, 15, and 16 in turn, and runs 
three fio tests to simulate different workloads. Based on the recommendations from https://arstechnica.com/gadgets/2020/02/how-fast-are-your-disks-find-out-the-open-source-way-with-fio/ the workloads are Single 4KiB random write process, 
16 parallel 64KiB random write processes, and Single 1MiB random write process. Each test is run in a dataset with matching recordsize, to avoid any write amplification. The script then displays the results of each workload in tabular form by recordsize and ashift.

If you would like to change the recordsize or ashifts used, you can easily edit the values in the script. Be careful with testing ashift=9, as with certain NVMe drives that are formatted to 4K blocksize, this can cause the 'zpool create' command to hang and lock up ZFS until the machine is restarted. Only use ashift=9 if you know your drive is formatted to 512kb blocksize.



