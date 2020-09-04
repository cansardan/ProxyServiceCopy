#!/bin/bash

# This script is called by deployDocker.sh during
# the service deployment or/and start.sh during startup
# depending on each individual service
# ConfigService has an example to setup DB properties
# DO NOT EDIT YOUR services.conf file by hand, use this script ONLY!

# TODO: Why are many sockets in CLOSE_WAIT with mod_proxy on httpd?
# https://access.redhat.com/solutions/457673
# We may need to tune keepalive duration on httpd

usage() {
    if [ "$#" -ne 4 ]; then
        echo "Usage: $0 add|del servicename servicehost/IP Port"
        echo "       NOTE:  The path is now the service name:"
        echo "              ex: engine, journey-explorer, auth,"
        echo "                  config, explore, sse, etc."
        echo "  e.g. $0 add ripAlbum 192.168.16.229 8888"
        echo "       use localhost for servicehost local PC"
	echo
	echo "To migrate an old config (pre 2.x) to 3.x, use the"
	echo "migrate option."
	echo "ex: $0 migrate"
        exit 1
    fi
}

add () {
    # Adding routing rules
    # sed -i doesn't work on Mac
    cp -p ${CONFFILE} $savedconf
    # BalancerMember http://10.101.1.89:7500

    # Verify the service exists in the migrated services.conf
    # if so then service existed at time of migration and 
    # entry exists in file, but not configured
    grep -q "Proxy balancer:\/\/${service}\>" ${savedconf}
    if [ $? -gt 0 ]; then
        read -p "${service} not exist,Are you sure you want to add[Yy|Nn]? " -n 1 -r
        echo    # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Adding..."
            addNewService > ${CONFFILE}
        else
            echo "Not Adding..."
            exit 0    
        fi
        
    else

        # Check to see if this ip/port is already configured
        grep -q "http://${ip}:${port}" $savedconf
        if [ $? -eq 0 ]; then
            echo "http://${ip}:${port} already configured"
            exit 0
        else
            # escape space to make it work for both Linux and Mac
            # sed -e "s/Proxy balancer\:\/\/${service}\>/Proxy balancer\:\/\/${service}\>\\
            #     BalancerMember http:\/\/${ip}:${port}/" \
            #     $savedconf > ${CONFFILE}
             sed -e "s|Proxy balancer://${service}>|Proxy balancer://${service}>\\
                BalancerMember http://${ip}:${port}|" \
                $savedconf > ${CONFFILE}

        fi
    fi
}
addNewService(){
    #add new balancer and Proxy entries for service.
    regex1="ProxyPass.*"
    regex2="</VirtualHost>.*"
    regex=$regex1
    balancerLine="         <Proxy balancer://${service}>\n                BalancerMember http://${ip}:${port}\n                Require all granted\n                ProxySet lbmethod=byrequests failonstatus=503,500\n\t</Proxy>\n"
    proxyLine="        ProxyPass /fox2/${service} balancer://${service}/fox2/${service}\n        ProxyPassReverse /fox2/${service} balancer://${service}/fox2/${service}\n"

    IFS=''
    while read line
        do
            if ! [[ ${line} =~ $regex ]]; then
                echo -e "${line}"
            else 
               if [[ $regex =~ $regex1 ]]; then
                   echo -e "${balancerLine}"
                   echo -e "${line}"

                   #chg regex to look for second entry point
                   regex=$regex2
                elif [[ $regex =~ $regex2 ]]; then
                    echo -e "${proxyLine}"
                    echo "${line}"
            fi
        fi
        done < $savedconf
}
del () {
    cp -p ${CONFFILE} $savedconf
    grep -q "http://${ip}:${port}" $savedconf
    if [ $? -eq 0 ]; then
        sed "/BalancerMember http:\/\/${ip}:${port}/d" \
             $savedconf > ${CONFFILE}
    else
        echo "http://${ip}:${port} does not exist"
        exit 0
    fi
}

migrate () {
    updated=false
    # Check to see if the current services.conf is version 4
    count=$(cat ${CONFDIR}/fox2/services.conf | grep 'journey-explorer' | wc -l)
    if [ $count -gt 0 ]; then
        echo 
	echo "Backing up the old services.conf to services.conf.OLD.pre-iris"
        /bin/cp ${CONFDIR}/fox2/services.conf ${CONFDIR}/fox2/services.conf.OLD.pre-iris
	echo 
	echo "Updating fox2/journey-explorer to iris"

	sed -i 's/fox2\/journey-explorer/iris/g' ${CONFDIR}/fox2/services.conf
	sed -i 's/journey-explorer/iris/g' ${CONFDIR}/fox2/services.conf
    updated=true
    fi

    #FD-3857 
    count=$(cat ${CONFDIR}/fox2/services.conf | grep 'failonstatus' | wc -l)
    if [ $count -eq 0 ]; then
    echo "Updating failonstatus on ProxySet"
    sed -i 's/ProxySet lbmethod=byrequests/ProxySet lbmethod=byrequests failonstatus=503,500/g' ${CONFDIR}/fox2/services.conf
    updated=true 
    fi 
  
	
    # Check to see if the current services.conf is version 2 or 3
    count=$(cat ${CONFDIR}/fox2/services.conf | grep "Proxy balancer" | wc -l)
    if [ $count -gt 0 ]; then

        if [ $updated=true ]; then
            echo "Your services.conf has been upgraded."
         else   
            echo "Your services.conf appears to be up-to-date.  If you wish to"
	        echo "re-run the migration, rename the services.conf.OLD file back"
	        echo "to services.conf (in your ProxyService_conf/fox2 directory)"
	        echo "and then re-run this script with the migrate option."
        fi  
        # FD-2655 - Remove any trailing /'s from ProxyPass and ReverseProxyPass
	#           (There should be NO trailing slashes in this file.)
        mv ${CONFFILE} $savedconf
        cat $savedconf | sed "s/\(.*\)\/$/\1/" > ${CONFFILE}

	exit
    fi

    echo
    echo "Backing up the old configuration to ${CONFDIR}/fox2/services.conf.OLD."
    /bin/mv ${CONFDIR}/fox2/services.conf ${CONFDIR}/fox2/services.conf.OLD
    /bin/cp ${CONFDIR}/fox2/services.conf.tmpl ${CONFDIR}/fox2/services.conf

    regex="ProxyPassReverse.*http://(.*):([0-9]{1,5})/fox2/(.*)"
    while read line
    do
        if [[ ${line} =~ ${regex} ]]; then
            ip=${BASH_REMATCH[1]}
            port=${BASH_REMATCH[2]}
            service=${BASH_REMATCH[3]}
            echo "Adding ip=${ip} port=${port} service=${service}"
	    add
        fi
    done < ${CONFDIR}/fox2/services.conf.OLD


    echo "Your services.conf has been upgraded."

    ${SCRIPTDIR}/reload.sh

    exit
}

# Gather parameters
service=$2 ip=$3 port=$4

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
    CONFDIR=$(pwd)/ProxyService_conf
else
    CONFDIR=${HOME}/ProxyService_conf
fi

CONFFILE=${CONFDIR}/fox2/services.conf
if [ ! -w ${CONFFILE} ]; then
    echo "Either ${CONFFILE} does not exist or"
    echo "you do not have permission to write"
    exit 1
fi
savedconf=${CONFFILE}.$(date +"%Y-%m-%d_%H:%M:%S")

if [ $# -eq 1 ] && [ "$1" == "migrate" ]; then
    migrate
elif [ $# -ne 4 ]; then
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

