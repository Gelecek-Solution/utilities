#!/bin/bash

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run this script as root."
        exit 1
    fi
}

# Function to get user input
gather_input() {
    echo "Enter the following network details:"
    read -p "Interface name (e.g., eth0, ens33): " INTERFACE
    read -p "Use DHCP? (yes/no): " USE_DHCP

    if [[ "$USE_DHCP" == "no" ]]; then
        read -p "IP Address (e.g., 192.168.1.10): " IPADDR
        read -p "Subnet Mask (e.g., 24 for /24): " SUBNET
        read -p "Gateway (e.g., 192.168.1.1): " GATEWAY
        read -p "DNS Servers (comma-separated, e.g., 8.8.8.8,8.8.4.4): " DNS
    fi
}

# Function to configure netplan
configure_netplan() {
    CONFIG_FILE="/etc/netplan/01-netcfg.yaml"
    echo "Configuring netplan..."

    if [[ "$USE_DHCP" == "yes" ]]; then
        cat <<EOF > $CONFIG_FILE
network:
  version: 2
  ethernets:
    $INTERFACE:
      dhcp4: yes
EOF
    else
        cat <<EOF > $CONFIG_FILE
network:
  version: 2
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IPADDR/$SUBNET
      gateway4: $GATEWAY
      nameservers:
        addresses: [${DNS//,/ }]
EOF
    fi

    echo "Applying netplan configuration..."
    netplan apply
}

# Function to configure CentOS/RedHat
configure_network_scripts() {
    CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-$INTERFACE"
    echo "Configuring network scripts..."

    if [[ "$USE_DHCP" == "yes" ]]; then
        cat <<EOF > $CONFIG_FILE
DEVICE=$INTERFACE
BOOTPROTO=dhcp
ONBOOT=yes
EOF
    else
        cat <<EOF > $CONFIG_FILE
DEVICE=$INTERFACE
BOOTPROTO=none
ONBOOT=yes
IPADDR=$IPADDR
NETMASK=$(ipcalc -m $IPADDR/$SUBNET | cut -d'=' -f2)
GATEWAY=$GATEWAY
DNS1=$(echo $DNS | cut -d',' -f1)
DNS2=$(echo $DNS | cut -d',' -f2)
EOF
    fi

    echo "Restarting network service..."
    systemctl restart network
}

# Function to test connectivity
test_connectivity() {
    echo "Testing connectivity..."
    echo "Pinging Gateway:"
    ping -c 4 $GATEWAY

    echo "Testing DNS resolution:"
    ping -c 4 google.com
}

# Main script execution
check_root
gather_input

if [ -f "/etc/netplan" ]; then
    configure_netplan
elif [ -d "/etc/sysconfig/network-scripts" ]; then
    configure_network_scripts
else
    echo "Unsupported system configuration. Exiting."
    exit 1
fi

test_connectivity

echo "Network configuration completed."
