#!/bin/sh

echo "start at $(date)"
echo ""

# Load Gost proxy configuration early to access all settings
if [ -f /data/vpnclient/gost.conf ]; then
    . /data/vpnclient/gost.conf
    echo "Configuration loaded from gost.conf"
fi

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

# Load BLOCK_UNMATCH_TRAFFIC setting
BLOCK_UNMATCH_TRAFFIC=${BLOCK_UNMATCH_TRAFFIC:-true}

if [ "$BLOCK_UNMATCH_TRAFFIC" = "true" ]; then
    echo "Applying security rules: Blocking non-matching traffic..."

    # Allow loopback traffic
    iptables -A OUTPUT -o lo -j ACCEPT

    # Allow established and related connections
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow DNS queries (required for domain resolution)
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

    # Allow traffic to VPN gateway (required for VPN connection)
    iptables -A OUTPUT -d 27.105.217.17 -j ACCEPT

    # Allow traffic through VPN tunnel (ppp0)
    iptables -A OUTPUT -o ppp0 -j ACCEPT

    # Allow traffic to VPN-routed networks via any interface
    # (OpenFortiVPN manages these routes automatically)

    # Function to check if a string is a domain name
    is_domain() {
        local entry="$1"
        # Not a CIDR notation and contains letters (likely a domain)
        if ! echo "$entry" | grep -q '/'; then
            if echo "$entry" | grep -q '[a-zA-Z]'; then
                return 0  # is domain
            fi
        fi
        return 1  # not domain
    }

    # Function to resolve domain to IP
    resolve_domain() {
        local domain="$1"
        local ip=""

        # Try getent first (works with /etc/hosts)
        ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -n 1)

        # If getent fails, try nslookup
        if [ -z "$ip" ]; then
            ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -n 1)
        fi

        echo "$ip"
    }

    # Read whitelist from configuration file
    WHITELIST_FILE="/data/vpnclient/white_list.conf"

    if [ -f "$WHITELIST_FILE" ]; then
        echo "Loading IP/Domain whitelist from $WHITELIST_FILE..."

        # Read whitelist and apply iptables rules
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip empty lines and comments
            case "$line" in
                ''|'#'*) continue ;;
            esac

            # Trim whitespace
            entry=$(echo "$line" | tr -d '[:space:]')

            if [ -z "$entry" ]; then
                continue
            fi

            # Check if entry is a domain name
            if is_domain "$entry"; then
                echo "  Resolving domain: $entry"
                resolved_ip=$(resolve_domain "$entry")

                if [ -n "$resolved_ip" ]; then
                    iptables -A OUTPUT -d "$resolved_ip" -j ACCEPT
                    echo "  ✓ Allowed: $entry → $resolved_ip"
                else
                    echo "  ✗ Failed to resolve: $entry"
                fi
            else
                # Direct IP or CIDR notation
                iptables -A OUTPUT -d "$entry" -j ACCEPT
                echo "  ✓ Allowed: $entry"
            fi
        done < "$WHITELIST_FILE"

        echo "Whitelist loaded successfully"
    else
        echo "Warning: Whitelist file not found at $WHITELIST_FILE"
        echo "Using default IP ranges..."

        # Fallback to default ranges if whitelist file doesn't exist
        iptables -A OUTPUT -d 192.168.100.0/24 -j ACCEPT
        iptables -A OUTPUT -d 192.168.101.0/24 -j ACCEPT
        iptables -A OUTPUT -d 192.168.102.0/24 -j ACCEPT
        iptables -A OUTPUT -d 192.168.103.0/24 -j ACCEPT
        iptables -A OUTPUT -d 10.0.0.0/16 -j ACCEPT

        echo "  ✓ Default ranges applied"
    fi

    # Drop all other outbound traffic to prevent IP leakage
    iptables -A OUTPUT -j REJECT --reject-with icmp-host-unreachable

    echo "Security rules applied: Non-matching traffic blocked"
    echo "  Allowed: VPN routes (as defined in white_list.conf)"
    echo "  Blocked: All other traffic (prevents IP exposure)"
else
    echo "Security mode disabled: All traffic allowed"
    echo "  Warning: Your host IP may be exposed for non-matching traffic"
fi

crond

echo "VPN started."
echo "Routing configured: Split-tunnel mode"
echo "  - Internal networks (192.168.x.x, 10.0.x.x) → VPN (ppp0)"
echo "  - Internet traffic → Direct (eth0)"
echo "VPN tunnel IP: $(ip -4 addr show ppp0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

# Start Gost HTTP/HTTPS proxy with authentication and detailed logging
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
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
