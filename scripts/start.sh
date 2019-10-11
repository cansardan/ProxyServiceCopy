#!/bin/bash

# Colors
if [[ -t 1 ]] && [[ -n $(tput colors) ]] && [[ $(tput colors) -ge 8 ]]; then
    RD=$(tput setaf 1); GR=$(tput setaf 2) YL=$(tput setaf 3) RS=$(tput sgr0)
fi

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# For Mac by default only files in /Users/, /Volumes/, /private/, and /tmp
# can be shared directly using -v bind mount.
if [ "$(uname)" != 'Darwin' ]; then
    cd ${SCRIPTDIR}/..
    LOGDIR=$(pwd)/logs
    cd ${SCRIPTDIR}/../..
    CONFDIR=$(pwd)/${SERVICE_NAME}_conf
else
    LOGDIR=${HOME}/logs
    CONFDIR=${HOME}/${SERVICE_NAME}_conf
fi
# Apps in Docker container runs root. The ${SERVICE_NAME}.log is owned by root
# Make sure the cf user can remove logs
mkdir -p $LOGDIR
chmod 775 $LOGDIR

docker images >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "\nEither the docker daemon is not running or you don't have permission to connect to docker\n"
    exit 1
fi

# Status: created, restarting, running, removing, paused, exited and dead
status=$(${SCRIPTDIR}/status.sh)
case "$status" in
    running)
        echo "${SERVICE_NAME}-${VERS} is already up and running"
        ;;
    restarting)
        echo "${SERVICE_NAME}-${VERS} is restarting"
        ;;
    removing)
        echo "${SERVICE_NAME}-${VERS} is removing"
        ;;
    paused|exited|dead)
        echo "Starting stopped container ${SERVICE_NAME}-${VERS}..."
        docker start ${SERVICE_NAME}-${VERS}
        if [ $? -ne 0 ]; then
            echo -e "\n$0 failed\n"
            exit 1
        fi
        ;;
    created|removed)
        echo "Starting ${SERVICE_NAME}-${VERS}..."
        docker run -dit -p ${PORT}:${PORT} -v ${LOGDIR}:/usr/local/apache2/htdocs/ -v ${CONFDIR}/fox2:/usr/local/apache2/conf/fox2 --restart always --name ${SERVICE_NAME}-${VERS} ${REPO_NAME}:${TAG}
        if [ $? -eq 0 ]; then
            echo -e "\n${SERVICE_NAME}-${TAG} successfully started"
            echo -e "The ${SERVICE_NAME} logs are in ${GR}${LOGDIR}${RS} directory"
        else
            echo -e "\nIf the image is missing download ${SERVICE_NAME}-${TAG}.sh and redploy the service\n"
            exit 1
        fi
        echo "Saving httpd.conf to ${CONFDIR}/httpd.conf.orig"
        docker cp ${SERVICE_NAME}-${VERS}:/usr/local/apache2/conf/httpd.conf ${CONFDIR}/httpd.conf.orig || exit 1
        /bin/cp ${CONFDIR}/httpd.conf.orig ${CONFDIR}/httpd.conf
        echo "Include conf/fox2/*.conf" >> ${CONFDIR}/httpd.conf
        echo "Adding Include conf/fox2/*.conf to httpd.conf"
        docker cp ${CONFDIR}/httpd.conf ${SERVICE_NAME}-${VERS}:/usr/local/apache2/conf/ || exit 1

        # Reload the configuration
        ${SCRIPTDIR}/reload.sh
        ;;
    *)
        # Should not happen. Just in case
        echo "The servcie status unknown"
        ;;
esac

