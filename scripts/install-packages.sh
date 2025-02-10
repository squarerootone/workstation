#!/bin/bash

# optional install brave browser
curl -fsS https://dl.brave.com/install.sh | sh

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
sudo dnf install -y code git gh
# why can't use PAT to upload to org's repo
# why have to use gh auth login to authenticate, any better way?

curl -fsSL https://get.docker.com | sh
curl -fsSL https://get.docker.com/rootless | sh
dockerd-rootless-setuptool.sh install