#!/bin/bash

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    echo "Creating tun/tap device."
    mknod /dev/net/tun c 10 200
fi

# clear existing configurations
find /etc/amnezia/amneziawg -mindepth 1 -delete

COUNTER=0
for s in $(find /config -name "*.conf")
do
  if test -f ${s}
  then
    COUNTER=$(( COUNTER + 1 ))
    basename=$(basename ${s})
    name=${basename%.conf}
    echo "Docker subnet $dockersubnet via $dockergw"
    echo awg interface "${name}" will be created from config file "${basename}"
    cp ${s} /etc/amnezia/amneziawg/${name}.conf
    chmod 600 /etc/amnezia/amneziawg/${name}.conf
    resolvconf -u
    awg-quick up ${name} &
    sleep 3
    ###
    # Restoring default local routes
    ###
    echo "Fixing local network routes after PostUp AWG"
    DROUTE=$(ip route | grep default | awk '{print $3}');
    HOMENET=192.168.0.0/16;
    HOMENET2=10.0.0.0/8;
    HOMENET3=172.16.0.0/12;
    ip route add $HOMENET3 via $DROUTE;
    ip route add $HOMENET2 via $DROUTE;
    ip route add $HOMENET via $DROUTE;
    iptables -I OUTPUT -d $HOMENET -j ACCEPT;
    iptables -A OUTPUT -d $HOMENET2 -j ACCEPT;
    iptables -A OUTPUT -d $HOMENET3 -j ACCEPT;
    iptables -A OUTPUT ! -o ${name} -m mark ! --mark $(awg show ${name} fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
    ###
    # Restored local routes
    ###
    /usr/bin/ssserver -vc /config/config.json &
    ss_pid=$!
    sleep 3
    ### --outbound-bind-interface ${name}
    #iptables -A FORWARD -i ${name} -j ACCEPT
    #iptables -A FORWARD -o ${name} -j ACCEPT
    #iptables -A FORWARD -i ${name} -o ${name} -j ACCEPT
    while kill -s 0 $ss_pid && awg show | grep -q ${name}
    do
      echo "Current IP: $(wget -q -O - http://ipecho.net/plain)"
      sleep 10
    done
    echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    echo "@ ShadowSocks or AWG server quit (or crashed) @"
    echo "@ Stopping container now...                   @"
    echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
    exit 1
  fi
done

if [[ $COUNTER -lt 1 ]]
then
  echo "There are no config files in the /config folder"
fi

/bin/sh
