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
cp -p ${CONFDIR}/fox2/services.conf ${CONFDIR}/fox2/services.conf.$(date +"%Y-%m-%d_%H:%M:%S")
grep -q $ip ${CONFDIR}/fox2/services.conf
if [ $? -eq 0 ]; then
    sed -i "/${ip}/s/.*/    ProxyPass \/$path http:\/\/${ip}:${port}\/config\//g" ${CONFDIR}/fox2/services.conf
else
    echo "Add one line"
    sed -i "/<VirtualHost/a\\
    \ \ \ \ ProxyPass \/$path http:\/\/${ip}:${port}\/config\/
    " ${CONFDIR}/fox2/services.conf
fi

docker exec ${SERVICE_NAME}-${VERS} apachectl -k graceful

echo -e "$0 successfully finished"

