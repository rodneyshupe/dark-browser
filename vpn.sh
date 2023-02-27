#!/usr/bin/env bash

OPENVPN_CONFIG="client"
OPENVPN_CONFIG_FILE="/etc/openvpn/${OPENVPN_CONFIG}.conf"

SCRIPT_NAME="$0"

function usage {
    echo "Usage: ${SCRIPT_NAME} [command]"
    if [ $# -eq 0 ] || [ -z "$1" ]; then
        echo ""
        echo "Command:"
        echo "  setup       Setup OpenVPN"
        echo "  rotate      Select a random VPN configuration to use"
        echo "  help        Display this usage message"
    fi
}

function parse_args () {
    while (( "$#" )); do
        case "$1" in
            setup)
                shift
                setup_vpn
                exit
                ;;
            rotate)
                shift
                rotate_vpn 1 1
                exit
                ;;
            help)
                echo "$(usage)"
                shift
                exit 0
                ;;
            *) # preserve positional arguments
                echo "ERROR: Unsupported command $1" >&2
                echo "$(usage)" >&2
                exit 1
                ;;
        esac
    done
    echo "ERROR: Missing command $1" >&2
    echo "$(usage)" >&2
    exit 1
}

function rotate_vpn() {
    local adjust_kill_switch=${1:-0} # defaults to off (0)
    local restart_openvpn=${2:-0} # defaults to off (0)

    sudo cp "$(find /etc/privadovpn/*.ovpn -type f | sort -R | head -1)" ${OPENVPN_CONFIG_FILE} && sudo sed -i -e 's/^auth-user-pass$/auth-user-pass \/etc\/openvpn\/privado/' ${OPENVPN_CONFIG_FILE}

    if [ $adjust_kill_switch -eq 1 ]; then
        adjust_kill_switch
    fi

    if [ $restart_openvpn -eq 1 ]; then
        sudo service openvpn@${OPENVPN_CONFIG} restart
    fi
}

function adjust_kill_switch() {
    local vpn_remote="$(sudo cat ${OPENVPN_CONFIG_FILE} | grep -e '^remote ' -1)"

    local server="$(echo "$vpn_remote" | grep remote | sed 's/^remote \(.*\) \(.*\)$/\1/')"
    local server_ip="$(dig $server +short)"
    local port="$(echo "$vpn_remote" | grep remote | sed 's/^remote \(.*\) \(.*\)$/\2/')"
    local proto="$(echo "$vpn_remote" | grep proto | sed 's/^proto \(.*\)$/\1/')"

    sudo ufw allow out to $server_ip port $port proto $proto >/dev/null
}

function setup_vpn_kill_switch() {
    echo "Setup Kill Switch"
    sudo systemctl enable ufw && sudo systemctl start ufw

    echo "  Deny traffic by default"
    sudo ufw default deny outgoing >/dev/null
    sudo ufw default deny incoming >/dev/null

    # allow local traffic
    subnets="$(ip -o -f inet addr show | awk '/scope global/ {print $4}')"
    while IFS= read -r subnet ; do
        echo "  Setup Allow rules for subnet $subnet"
        sudo ufw allow in to $subnet >/dev/null
        sudo ufw allow out to $subnet >/dev/null
    done <<< "$subnets"

    echo "  Add VPN server to allow rules"
    adjust_kill_switch

    echo -n "  Allow outbound on tun interface "
    interface=$(ip addr | grep 'inet ' | grep --invert-match 'inet 127.0.0.' | grep --invert-match "inet "$(ping $HOSTNAME -c 1 | head -1 | sed -e 's/.*(\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)\.[0-9]\{1,3\}).*/\1./')"" | grep --only-matching ' [^ ]*$' | sed 's/^[ ]*//')
    echo "($interface)"
    sudo ufw allow out on $interface from any to any >/dev/null
    #sudo ufw allow in on tun0 from any to any >/dev/null
}

function setup_auth_file() {
    local auth_file="${1:-/etc/openvpn/privado}"

    echo "Setup VPN Auth file (${auth_file})"
    read -p "  Enter PrivadoVPN username: " username

    password="x"
    verify="y"
    while [[ "$password" != "$verify" ]]; do
        echo -n "  Enter PrivadoVPN password: "
        read -s password
        echo -n "  Re-enter PrivadoVPN password: "
        read -s verify

        [[ "$password" != "$verify" ]]; echo "  Password doesn't match. Retry."
    done

    sudo bash -c "echo '$username' > "${auth_file}""
    sudo bash -c "echo '$password' >> "${auth_file}""
    sudo chmod 400 "${auth_file}"
}

function setup_vpn() {
    ori_ip="$(curl ifconfig.co)"

    echo "Install open VPN"
    sudo apt update && sudo apt install openvpn ufw -y /dev/null

    echo "Remove any previous launchers"
    sudo update-rc.d -f openvpn remove

    echo "Get Privado VPN configs"
    wget https://privadovpn.com/apps/ovpn_configs.zip >/dev/null
    sudo unzip -d /etc/privadovpn/ ovpn_configs.zip >/dev/null

    # Setup the auth file
    setup_auth_file /etc/openvpn/privado

    echo "Pick a random VPN configuration"
    rotate_vpn

    # TODO: Add cron job


    #TODO: Setup Kill Switch
    setup_vpn_kill_switch

    echo "Set OpenVPN to start on boot"
    sudo -i -e 's/^[[:space]]*#[[:space]]*AUTOSTART="all"/AUTOSTART="all"/' /etc/default/openvpn
    sudo systemctl enable openvpn@${OPENVPN_CONFIG}.service
    sudo systemctl daemon-reload
    sudo service openvpn@${OPENVPN_CONFIG} start

    sleep 5

    new_ip="$(curl ifconfig.co)"
    if [[ "$new_ip" != "$ori_ip" ]]; then
        echo "OpenVPN Configured New IP: $new_ip"
    else
        echo "OpenVPN configuration problem. (IP: $new_ip)"
    fi
}

parse_args $@
