#!/bin/bash

# check if any partition on the disk
lsblk -f /dev/sdb
sudo btrfs filesystem show /dev/sdb

sudo mkfs.btrfs /dev/sdb
sudo mkdir -pv /mnt/btrfs
sudo mount /dev/sdb /mnt/btrfs

sudo btrfs subvolume list /mnt/btrfs
sudo btrfs subvolume create /mnt/btrfs/hailong

sudo rsync -aAXv /home/hailong/hailong/* /mnt/btrfs/hailong
sudo mv /home/hailong /home/hailong.old
sudo mkdir /home/hailong
# sudo mount -o subvol=hailong /dev/sdb /home/hailong

sudo blkid /dev/sdb
sudo nano /etc/fstab
# UUID=<UUID> /home/hailong btrfs compress=zstd:1,subvol=hailong 0 0

sudo systemctl daemon-reload
sudo mount -a
df -h /home/hailong
sudo btrfs subvolume list /home/hailong

sudo reboot
sudo rm -rf /home/hailong.old

