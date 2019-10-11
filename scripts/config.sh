#!/bin/bash

# This script is called by deployDocker.sh during
# the service deployment or/and start.sh during startup
# depending on each individual service
# ConfigService has an example to setup DB properties

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 ServiceName ServiceHostIp Path port"
    echo "  e.g. $0 ConfigService 192.168.16.229 config 8888"
    exit
fi

svc=$1 ip=$2 path=$3 port=$4

# need to map docker localhost to docker host localhost IP
if [ "$ip" = localhost ]; then
    if [ "$(uname)" != 'Darwin' ]; then
        ip=$(ip route show default | awk '/default/ {print $3}')
    else
        # ip=docker.for.mac.localhost
        # after 18.03
        ip=host.docker.internal
    fi   
fi

# run in makeself env ${BASH_SOURCE[0]} is the extact dir
if [ -n "$INSTDIR" ]; then
    SCRIPTDIR=$INSTDIR/bin
else
    SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
fi

cd ${SCRIPTDIR}/../..
# For Mac by default only files in /Users/, /Volumes/, /private/, and /tmp
# can be shared directly using -v bind mount.
if [ "$(uname)" != 'Darwin' ]; then
    CONFDIR=$(pwd)/${SERVICE_NAME}_conf
else
    CONFDIR=${HOME}/${SERVICE_NAME}_conf
fi

# Adding routing rules
# sed -i doesn't work on Mac
savedconf=${CONFDIR}/fox2/services.conf.$(date +"%Y-%m-%d_%H:%M:%S")
cp -p ${CONFDIR}/fox2/services.conf $savedconf
grep -q "/$ip:" $savedconf
if [ $? -eq 0 ]; then
    sed "/ProxyPass .*http:\/\/${ip}:/s/.*/    ProxyPass \/$path http:\/\/${ip}:${port}\/config\//;
         /ProxyPassReverse.*http:\/\/${ip}:/s/.*/    ProxyPassReverse \/$path http:\/\/${ip}:${port}\/config\// \
        " $savedconf > ${CONFDIR}/fox2/services.conf
else
    # escaple space to make it work for both Linux and Mac
    sed "/ProxyPreserveHost On/a\\
\ \ \ \ ProxyPass \/$path http:\/\/${ip}:${port}\/config\/\\
\ \ \ \ ProxyPassReverse \/$path http:\/\/${ip}:${port}\/config\/\\
\\
       " $savedconf > ${CONFDIR}/fox2/services.conf
fi

${SCRIPTDIR}/reload.sh

echo -e "$0 successfully finished"

