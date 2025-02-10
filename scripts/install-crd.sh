#!/bin/bash

# Determine the package manager and OS type
detect_os() {
    if command -v apt-get &> /dev/null; then
        OS_TYPE="ubuntu"
        PKG_MANAGER="apt-get"
    elif command -v dnf &> /dev/null; then
        OS_TYPE="fedora"
        PKG_MANAGER="dnf"
    else
        echo "Unsupported OS type"
        exit 1
    fi
}

# PAM configuration for Chrome Remote Desktop
PAM_CONFIG=$(cat << EOF
auth       required    pam_unix.so
account    required    pam_unix.so
password   required    pam_unix.so
session    required    pam_unix.so
session    optional    pam_keyinit.so force revoke
session    optional    pam_loginuid.so
EOF
)

# Function to install desktop environment (default to GNOME)
install_desktop_environment() {
    local desktop_env=${1:-gnome}

    echo "Installing desktop environment: $desktop_env"

    if [ "$OS_TYPE" == "ubuntu" ]; then
        sudo apt-get update -y && sudo apt-get upgrade -y
        case $desktop_env in
            gnome)
                sudo apt-get install -y ubuntu-gnome-desktop
                # TODO figure out how to install smaller package list instead of the full gnome destop
                sudo dpkg-reconfigure gdm3
                ;;
            xfce)
                sudo apt-get install -y xfce4
                ;;
            none)
                echo "Skipping desktop environment installation."
                ;;
            *)
                echo "Unsupported desktop environment: $desktop_env"
                exit 1
                ;;
        esac
    elif [ "$OS_TYPE" == "fedora" ]; then
        sudo dnf update -y
        
        # note that `groupinstall` seems to have been replaced by `group install`.
        # and if that doesn't work, we can go with the dnf install @[package] syntax instead
        # and the metadata doesn't seem to be available on fedora cloud for fedora workstation
        # so we will install individual group instead. in this case we'll start with gnome desktop
        case $desktop_env in
            gnome)
            # note that there's some issue preventing the default ptyxis terminal from starting
            # however gnome-terminal works fine out of the box once installed
            # we're skipping the troubleshooting here just by installing it
                sudo dnf install -y @gnome-desktop gnome-terminal
                ;;
            xfce)
                sudo dnf install -y @xfce-desktop
                ;;
            none)
                echo "Skipping desktop environment installation."
                ;;
            *)
                echo "Unsupported desktop environment: $desktop_env"
                exit 1
                ;;
        esac
    fi
}

# Function to install Chrome Remote Desktop manually
install_crd() {
    local desktop_env=${1:-gnome}

    echo "Installing Chrome Remote Desktop"

    if [ "$OS_TYPE" == "ubuntu" ]; then
        sudo apt-get install -y curl
        curl -O https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
        sudo dpkg -i chrome-remote-desktop_current_amd64.deb
        sudo apt-get --fix-broken install -y
    elif [ "$OS_TYPE" == "fedora" ]; then
        sudo dnf install -y curl binutils
        mkdir -pv chrome-remote-desktop
        cd chrome-remote-desktop
        curl -O https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
        ar x chrome-remote-desktop_current_amd64.deb
# note should create a folder data then extract into it. 4 dirs etc lib opt usr
        tar -xf data.tar.xz

        sudo cp -r opt/google /opt/google
        sudo chmod -R 755 /opt/google/chrome-remote-desktop
        sudo cp -r lib/systemd/system/* /lib/systemd/system/

        # don't copy, just nano and create the file directly, syntax diff on fedora vs debian
        # sudo cp -r etc/pam.d/ /etc/
        echo "$PAM_CONFIG" | sudo tee /etc/pam.d/chrome-remote-desktop > /dev/null
        sudo chmod 644 /etc/pam.d/chrome-remote-desktop

        cd ..
        rm -rf chrome-remote-desktop

        echo "Installing dependencies"
        sudo dnf install -y xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-xinit xdpyinfo xrandr setxkbmap dbus-x11 xorg-x11-server-Xvfb dpkg
        sudo dnf install -y python3-pyxdg python3-packaging
    fi

    case $desktop_env in
        gnome)
            echo "exec /usr/bin/gnome-session" > ~/.chrome-remote-desktop-session
            ;;
        xfce)
            echo "exec /usr/bin/xfce4-session" > ~/.chrome-remote-desktop-session
            ;;
    esac
}

# Start from a Fedora Cloud image here, launch it directly into Azure, then customise it
# https://fedoraproject.org/cloud/download#cloud_launch

# Parse command line arguments
parse_arguments() {
    desktop_env="gnome"
    while [ "$#" -gt 0 ]; do
        case $1 in
            --desktop-env) desktop_env="$2"; shift 2;;
            *) echo "Unknown parameter passed: $1"; exit 1;;
        esac
    done
}

# Main script execution
main() {
    detect_os
    parse_arguments "$@"
    install_desktop_environment "$desktop_env"
    install_crd "$desktop_env"

    echo "Installation complete. Please visit the following URL to authorize this machine for Chrome Remote Desktop:"
    echo "https://remotedesktop.google.com/headless"
    echo "Follow the instructions to obtain the authorization code."
}

main "$@"
