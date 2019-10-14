#!/bin/bash

# This script is called by deployDocker.sh during
# the service deployment or/and start.sh during startup
# depending on each individual service
# ConfigService has an example to setup DB properties

usage() {
    if [ "$#" -ne 4 ]; then
        echo "Usage: $0 add|del ServiceName ServiceHostIp Path Port"
        echo "  e.g. $0 add ConfigService 192.168.16.229 config 8888"
        exit 1
    fi
}

add () {
    # Adding routing rules
    # sed -i doesn't work on Mac
    cp -p ${CONFFILE} $savedconf
    # ProxyPass /config http://192.168.16.229:8888/config/
    grep -q "http://${ip}:${port}/${path}" $savedconf
    if [ $? -eq 0 ]; then
        echo "http://${ip}:${port}/${path} already configured"
        exit 0
    else
        # escaple space to make it work for both Linux and Mac
        sed "/ProxyPreserveHost On/a\\
\ \ \ \ ProxyPass \/$path http:\/\/${ip}:${port}\/${path}\/\\
\ \ \ \ ProxyPassReverse \/$path http:\/\/${ip}:${port}\/${path}\/\\
           " $savedconf > ${CONFFILE}
    fi
}

del () {
    cp -p ${CONFFILE} $savedconf
    grep -q "http://${ip}:${port}/${path}" $savedconf
    if [ $? -eq 0 ]; then
        sed "/ProxyPass \/${path} http:\/\/${ip}:${port}\/${path}\//d;
             /ProxyPassReverse \/${path} http:\/\/${ip}:${port}\/${path}\//d \
            " $savedconf > ${CONFFILE}
    else
        echo "http://${ip}:${port}/${path} does not exist"
        exit 0
    fi
}

svc=$2 ip=$3 path=$4 port=$5
# remove / at the beginning
path=${path#/}
# escape / for sed
path=${path//\//\\/}

# need to map docker localhost to docker host localhost IP
if [ "$ip" = localhost ]; then
    if [ "$(uname)" != 'Darwin' ]; then
        ip=$(ip addr show docker0 | awk '/inet / {print $2}')
        ip=${ip%/*}
    else
        # Docker for Mac v 17.12 to v 18.02
        # ip=docker.for.mac.host.internal
        # Docker v 18.03 and above
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

CONFFILE=${CONFDIR}/fox2/services.conf
if [ ! -w ${CONFFILE} ]; then
    echo "Either ${CONFFILE} does not exist or"
    echo "you do not have permission to write"
    exit 1
fi
savedconf=${CONFFILE}.$(date +"%Y-%m-%d_%H:%M:%S")

if [ $# -ne 5 ]; then
    usage
fi
case "$1" in
    add)
        add
        ;;
    del)
        del
        ;;
    *)
        usage 
esac

${SCRIPTDIR}/reload.sh

echo -e "$0 successfully finished"

