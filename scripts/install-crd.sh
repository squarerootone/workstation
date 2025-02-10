#!/bin/bash

# Start from a Fedora Cloud image here, launch it directly into Azure, then customise it
# https://fedoraproject.org/cloud/download#cloud_launch

# Update system and install desktop manager
sudo dnf update -y
sudo dnf install -y @gnome-desktop gnome-terminal
# note that `groupinstall` seems to have been replaced by `group install`.
# and if that doesn't work, we can go with the dnf install @[package] syntax instead
# and the metadata doesn't seem to be available on fedora cloud for fedora workstation
# so we will install individual group instead. in this case we'll start with gnome desktop
# Alternatively these are other groups that we can try
# sudo dnf group install -y "Workstation"
# sudo dnf group install -y "Xfce Desktop"
# note that there's some issue preventing the default ptyxis terminal from starting
# however gnome-terminal works fine out of the box once installed
# we're skipping the troubleshooting here just by installing it

###############################
# Download the deb package, and work around to install on fedora
sudo dnf install binutils -y
mkdir -pv chrome-remote-desktop
cd chrome-remote-desktop
curl https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb -o chrome-remote-desktop_current_amd64.deb
ar x chrome-remote-desktop_current_amd64.deb
# note should create a folder data then extract into it. 4 dirs etc lib opt usr
tar -xf data.tar.xz

sudo cp -r opt/google /opt/google
sudo chmod -R 755 /opt/google/chrome-remote-desktop
sudo cp -r lib/systemd/system/* /lib/systemd/system/

# don't copy, just nano and create the file directly, syntax diff on fedora vs debian
# sudo cp -r etc/pam.d/ /etc/
cat << EOF >> chrome-remote-desktop
auth       required    pam_unix.so
account    required    pam_unix.so
password   required    pam_unix.so
session    required    pam_unix.so
session    optional    pam_keyinit.so force revoke
session    optional    pam_loginuid.so
EOF
sudo cp chrome-remote-desktop /etc/pam.d/chrome-remote-desktop
sudo chmod 644 /etc/pam.d/chrome-remote-desktop

cd ..
rm -rf chrome-remote-desktop

# install dependencies
sudo dnf install xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-xinit xdpyinfo xrandr setxkbmap dbus-x11 xorg-x11-server-Xvfb dpkg -y
sudo dnf install python3-pyxdg python3-packaging -y

###############################
# Configure crd to run on gnome
# echo "exec /usr/bin/xfce4-session" > ~/.chrome-remote-desktop-session
echo "exec /usr/bin/gnome-session" > ~/.chrome-remote-desktop-session

# [Sign in - Google Accounts](https://remotedesktop.google.com/headless)
# Authorise and link the workstation to the account as per Set up via SSH section
