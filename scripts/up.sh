#!/bin/sh

echo "start at $(date)"
echo ""
echo "VPN starting..."
/data/openfortivpn-1.24.0/openfortivpn -v -c /data/vpnclient/forti.conf 2>&1 &
sleep 3

while [ -z "$(ip a | grep 'scope global ppp0')" ];
do
    echo "VPN connecting..."
    sleep 1
done

echo "ppp0 interface is up, waiting for route configuration..."
sleep 3

# Wait for openfortivpn to finish route configuration
while [ -z "$(ip route | grep '192.168.100.0/24 dev ppp0')" ];
do
    echo "Waiting for VPN routes..."
    sleep 1
done

echo "VPN routes configured, applying NAT rules..."

iptables -t nat -I POSTROUTING -o ppp0 -j MASQUERADE

# Note: This VPN is configured in split-tunnel mode
# Only specific internal networks (192.168.100-103.0/24, 10.0.0.0/16) route through VPN
# All other traffic (including internet access) goes through eth0

crond

echo "VPN started."
echo "Routing configured: Split-tunnel mode"
echo "  - Internal networks (192.168.x.x, 10.0.x.x) → VPN (ppp0)"
echo "  - Internet traffic → Direct (eth0)"
echo "VPN tunnel IP: $(ip -4 addr show ppp0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

# Load Gost proxy configuration
if [ -f /data/vpnclient/gost.conf ]; then
    . /data/vpnclient/gost.conf

    # Start Gost HTTP/HTTPS proxy with authentication and detailed logging
    echo "Starting Gost proxy server with detailed logging..."
    /usr/local/bin/gost \
        -L "http://${PROXY_USER}:${PROXY_PASS}@${PROXY_ADDR}" \
        -L "socks5://${PROXY_USER}:${PROXY_PASS}@:1080" \
        -L "socks5://:1081" \
        -D \
        2>&1 | tee -a /var/log/gost.log &

    echo "Gost proxy started:"
    echo "  - HTTP proxy: 8080 (需要认证)"
    echo "  - SOCKS5 proxy: 1080 (需要认证)"
    echo "  - SOCKS5 proxy: 1081 (无需认证，用于 FoxyProxy)"
    echo "Authentication: ${PROXY_USER}:${PROXY_PASS}"
    echo "Detailed logs: /var/log/gost.log"
else
    echo "Warning: Gost configuration file not found!"
fi

while [ true ]; do sleep 1; done
