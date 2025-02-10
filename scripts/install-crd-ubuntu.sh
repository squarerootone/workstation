#!/bin/bash

# Update system and install desktop manager
sudo apt update && sudo apt upgrade -y
# sudo apt install xfce4
sudo apt install ubuntu-gnome-desktop -y
# to figure out smaller package list, not the full gnome destop
sudo dpkg-reconfigure gdm3

###############################
# Install wget to download the deb package and install it
sudo apt install wget
wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
sudo dpkg -i chrome-remote-desktop_current_amd64.deb
sudo apt --fix-broken install

###############################
# Configure crd to run on gnome
# echo "exec /usr/bin/xfce4-session" > ~/.chrome-remote-desktop-session
echo "exec /usr/bin/gnome-session" > ~/.chrome-remote-desktop-session

# check if service is masked by checking for sym link to /dev/null
ls -l /usr/lib/systemd/system/chrome-remote-desktop.service
sudo rm /usr/lib/systemd/system/chrome-remote-desktop.service

# current crd connection uses X, this will prevent wayland from starting unnecessary services
sudo nano /etc/gdm/custom.conf
# uncomment this line WaylandEnable=false
sudo systemctl restart gdm

# [Sign in - Google Accounts](https://remotedesktop.google.com/headless)
# Authorise and link the workstation to the account as per Set up via SSH section

###############################
# start the service
sudo systemctl enable chrome-remote-desktop@$USER
sudo systemctl start chrome-remote-desktop@$USER

# check that service is working and no error reported
sudo systemctl status chrome-remote-desktop@$USER

# you should now be able to remote in via crd's web interface under Remote Access section

###############################

# check wayland or X server is being used
echo $XDG_SESSION_TYPE
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type
ps -e | grep -E 'Xorg|wayland'

# reboot and check that it still works
sudo reboot

###############################

# not sure why there's this issue with the network on start up
# seems to only happen to ubuntu for now, not fedora.
# it'll timeout itself after 3-4 min and complete the rest of the booting cycle
# %%
# Starting systemd-networkd-wait-onl…ait for Network to be Configured...
# [    **] Job systemd-networkd-wait-online.se…tart running (1min 42s / no limit)
# %%
