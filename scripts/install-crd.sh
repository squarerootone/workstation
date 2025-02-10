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
    echo "$OS_TYPE"
}

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

# Function to install applications
install_apps() {
    local os_type="fedora"
    local update_system=false
    local apps=()
    while [ "$#" -gt 0 ]; do
        case $1 in
            --os) os_type="$2"; shift 2;;
            --update) update_system=true; shift;;
            *) apps+=("$1"); shift;;
        esac
    done

    if $update_system; then
        echo "Updating system..."
        if [ "$os_type" == "ubuntu" ]; then
            sudo apt-get update -y && sudo apt-get upgrade -y
        elif [ "$os_type" == "fedora" ]; then
            sudo dnf update -y
        else
            echo "Unsupported OS type: $os_type"
            exit 1
        fi
    fi

    if [ ${#apps[@]} -gt 0 ]; then
        echo "Installing applications: ${apps[*]}"

        if [ "$os_type" == "ubuntu" ]; then
            sudo apt-get install -y "${apps[@]}"
        elif [ "$os_type" == "fedora" ]; then
            sudo dnf install -y "${apps[@]}"
        else
            echo "Unsupported OS type: $os_type"
            exit 1
        fi
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
    local os_type=${1:-$OS_TYPE}
    local desktop_env=${2:-gnome}
    local desktop_env_package = ""

    # note that `groupinstall` seems to have been replaced by `group install`.
    # and if that doesn't work, we can go with the dnf install @[package] syntax instead
    # and the metadata doesn't seem to be available on fedora cloud for fedora workstation
    # so we will install individual group instead. in this case we'll start with gnome desktop
    case $desktop_env in
        gnome)
            # note that there's some issue preventing the default ptyxis terminal from starting
            # however gnome-terminal works fine out of the box once installed
            # we're skipping the troubleshooting here just by installing it
            if [ "$os_type" == "ubuntu" ]; then desktop_env_package = "ubuntu-gnome-desktop"
            elif [ "$os_type" == "fedora" ]; then desktop_env_package = "@gnome-desktop gnome-terminal"
            fi
            ;;
        xfce)
            if [ "$os_type" == "ubuntu" ]; then desktop_env_package = "xfce4"
            elif [ "$os_type" == "fedora" ]; then desktop_env_package = "@xfce-desktop"
            fi
            ;;
        none)
            echo "Skipping desktop environment installation."
            exit 0
            ;;
        *)
            echo "Unsupported desktop environment: $desktop_env"
            exit 1
            ;;
    esac

    echo "Installing desktop environment: $desktop_env"
    install_apps --os "$os_type" --update $desktop_env_package
    if [ "$os_type" == "ubuntu" && "$desktop_env" == "gnome" ]; then
        # TODO figure out how to install smaller package list instead of the full gnome destop
        sudo dpkg-reconfigure gdm3
    fi
}

# Function to install Chrome Remote Desktop manually
install_crd() {
    local os_type=${1:-$OS_TYPE}
    local desktop_env=${2:-gnome}

    echo "Installing Chrome Remote Desktop"

    mkdir -pv chrome-remote-desktop
    cd chrome-remote-desktop
    install_apps --os $os_type curl
    curl -O https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb

    if [ "$os_type" == "ubuntu" ]; then
        sudo dpkg -i chrome-remote-desktop_current_amd64.deb
        sudo apt-get --fix-broken install -y
    elif [ "$os_type" == "fedora" ]; then
        install_apps --os $os_type binutils
        # note should create a folder data then extract into it. 4 dirs etc lib opt usr
        ar x chrome-remote-desktop_current_amd64.deb
        tar -xf data.tar.xz

        sudo cp -r opt/google /opt/google
        sudo chmod -R 755 /opt/google/chrome-remote-desktop
        sudo cp -r lib/systemd/system/* /lib/systemd/system/

        # don't copy, just nano and create the file directly, syntax diff on fedora vs debian
        # sudo cp -r etc/pam.d/ /etc/
        echo "$PAM_CONFIG" | sudo tee /etc/pam.d/chrome-remote-desktop > /dev/null
        sudo chmod 644 /etc/pam.d/chrome-remote-desktop

        echo "Installing dependencies"
        install_apps --os $os_type xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-xinit xdpyinfo xrandr setxkbmap dbus-x11 xorg-x11-server-Xvfb dpkg
        install_apps --os $os_type python3-pyxdg python3-packaging
    fi

    cd ..
    rm -rf chrome-remote-desktop

    case $desktop_env in
        gnome)
            echo "exec /usr/bin/gnome-session" > ~/.chrome-remote-desktop-session
            ;;
        xfce)
            echo "exec /usr/bin/xfce4-session" > ~/.chrome-remote-desktop-session
            ;;
    esac
}

# Main script execution
main() {
    local os_type
    os_type=$(detect_os)
    parse_arguments "$@"
    install_desktop_environment "$os_type" "$desktop_env"
    install_crd "$os_type" "$desktop_env"

    echo "Installation complete. Please visit the following URL to authorize this machine for Chrome Remote Desktop:"
    echo "https://remotedesktop.google.com/headless"
    echo "Follow the instructions to obtain the authorization code."
}

# Start from a Fedora Cloud image here, launch it directly into Azure, then customise it
# https://fedoraproject.org/cloud/download#cloud_launch
main "$@"
