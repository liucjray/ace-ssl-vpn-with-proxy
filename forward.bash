#!/bin/bash env

ip route add 192.168.100.0/24 via 10.73.0.5
ip route add 192.168.101.0/24 via 10.73.0.5
ip route add 192.168.102.0/24 via 10.73.0.5
ip route add 192.168.103.0/24 via 10.73.0.5

iptables -I FORWARD -i ens18 -d 192.168.100.0/24 -j ACCEPT
iptables -I FORWARD -i ens18 -d 192.168.101.0/24 -j ACCEPT
iptables -I FORWARD -i ens18 -d 192.168.102.0/24 -j ACCEPT
iptables -I FORWARD -i ens18 -d 192.168.103.0/24 -j ACCEPT

iptables -t nat -I POSTROUTING -d 192.168.100.0/24 -j MASQUERADE
iptables -t nat -I POSTROUTING -d 192.168.101.0/24 -j MASQUERADE
iptables -t nat -I POSTROUTING -d 192.168.102.0/24 -j MASQUERADE
iptables -t nat -I POSTROUTING -d 192.168.103.0/24 -j MASQUERADE
