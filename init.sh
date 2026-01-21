#!/bin/bash

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
    echo awg interface "${name}" will be created from config file "${basename}"
    cp ${s} /etc/amnezia/amneziawg/${name}.conf
    chmod 600 /etc/amnezia/amneziawg/${name}.conf
    resolvconf -u
    awg-quick up ${name} &
    wg_pid=$!
    #/usr/bin/ss-tunnel -s engage.cloudflareclient.com -p 4500 -k bruhlmao -t 300 -b 0.0.0.0 -l 4096 -u &
    /usr/bin/ss-server -vc /config/config.json -i ${name} &
    ss_pid=$!
    #iptables -A FORWARD -i ${name} -j ACCEPT
    #iptables -A FORWARD -o ${name} -j ACCEPT
    #iptables -A FORWARD -i ${name} -o ${name} -j ACCEPT
    ### Do routing
    #iptables -t nat -A PREROUTING -i ${name} -p tcp -j DNAT --to-destination 127.0.0.1:4096
    #iptables -t nat -D PREROUTING -i ${name} -p tcp -j DNAT --to-destination 127.0.0.1:4096
    #iptables -t nat -A PREROUTING -i ${name} -p udp -j DNAT --to-destination 127.0.0.1:4096
    #iptables -t nat -D PREROUTING -i ${name} -p udp -j DNAT --to-destination 127.0.0.1:4096
    ### End routing
    #sstun_port=$(jq '.server_port' /config/config.json)
    #sstun_pass=$(jq '.password' /config/config.json)
    #sstun_method=$(jq '.method' /config/config.json)
    while kill -s 0 $ss_pid # && kill -s 0 $wg_pid
    do
      curl -sL http://ipecho.net/plain
      sleep 3
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
