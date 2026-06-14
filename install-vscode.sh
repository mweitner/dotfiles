#!/bin/sh

# https://code.visualstudio.com/docs/setup/linux#_rhel-fedora-and-centos-based-distributions

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
printf '%s\n' \
	'[code]' \
	'name=Visual Studio Code' \
	'baseurl=https://packages.microsoft.com/yumrepos/vscode' \
	'enabled=1' \
	'autorefresh=1' \
	'type=rpm-md' \
	'gpgcheck=1' \
	'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' \
	| sudo tee /etc/yum.repos.d/vscode.repo >/dev/null

dnf check-update
sudo dnf install code # or code-insiders
