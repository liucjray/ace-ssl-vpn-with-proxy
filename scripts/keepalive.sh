#!/bin/sh

export check;

if /bin/ping -c 1 -q 192.168.103.10 > /dev/null
then
    check="Y";
else
    check="N";
fi

echo $check

if [ "$check" = "N" ]
then
    echo 'VPN maybe disconnected.'
fi

date >> /tmp/cronlog
echo "${check}" >> /tmp/cronlog
