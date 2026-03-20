#!/bin/bash
# 1. Interface Definitions
USB_IF="enx00e04cb828b5"
VPN_IF="tun0"

echo "Step 1: Forcing Forwarding & Disabling VPN 'Kill-Switch' Logic..."
sudo sysctl -w net.ipv4.ip_forward=1
# Disable Reverse Path Filtering (Crucial: prevents dropping 'asymmetric' VPN traffic)
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.conf.$USB_IF.rp_filter=0
sudo sysctl -w net.ipv4.conf.$VPN_IF.rp_filter=0

echo "Step 2: Cleaning and Prioritizing Forwarding Rules..."
# Force absolute priority for your machine network
sudo iptables -P FORWARD ACCEPT
sudo iptables -F FORWARD
sudo iptables -I FORWARD 1 -i $USB_IF -j ACCEPT
sudo iptables -I FORWARD 2 -o $USB_IF -j ACCEPT

echo "Step 3: Setting NAT Masquerade for the VPN Tunnel..."
sudo iptables -t nat -F
# This rule hides the DC5 (192.168.2.130) behind your VPN IP (172.28.216.91)
sudo iptables -t nat -A POSTROUTING -o $VPN_IF -j MASQUERADE

echo "Step 4: Applying TCP MSS Clamping (Fixes MTU issues over VPN)..."
# VPNs have smaller MTU; without this, HTTPS handshakes fail
sudo iptables -t mangle -F
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

echo "Step 5: Refreshing local network environment..."
sudo ip neighbor flush dev $USB_IF
sudo systemctl restart dnsmasq

echo "DONE. Try 'wget https://www.google.de' on the DC5 now."
