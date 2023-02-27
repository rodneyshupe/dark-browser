# dark-browser

These scripts allow for the easy setup of a VM on Proxmox that only allows browsing over VPN.

This is specific for my VPN (PrivdoVPN) but could easily be adapted for others.

This sets up a way to rotate the VPN config file and ensure a kill switch.

## Setup

### Create VM

Log into Proxmox UI and create a new VM using lubutu as the iso.

### Setup SSH

Connext to the new VM and open a terminal and enter the following:

```sh
sudo apt update && sudo apt upgrade && sudo apt install openssh-server ufw -y
sudo systemctl enable ssh
sudo ufw allow ssh
#sudo ufw allow 5901:5910/tcp # This would be for VNC if that doesn't work from proxmox
```

You should now be able to ssh into the new VM.  If not check the status of SSH with `sudo systemctl status ssh`

### Run the rest of the setup

Log into ssh or execute in the same terminal the rest of the setup.

```sh
curl -sSL https://raw.githubusercontent.com/rodneyshupe/dark-browser/main/setup.sh | sudo bash
```
