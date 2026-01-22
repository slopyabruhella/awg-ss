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
    sleep 4
    /usr/bin/ss-server -vc /config/config.json -i ${name} &
    ss_pid=$!
    #iptables -A FORWARD -i ${name} -j ACCEPT
    #iptables -A FORWARD -o ${name} -j ACCEPT
    #iptables -A FORWARD -i ${name} -o ${name} -j ACCEPT
    sleep 6
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
