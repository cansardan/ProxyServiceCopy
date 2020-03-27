#!/bin/bash

# Colors
if [[ -t 1 ]] && [[ -n $(tput colors) ]] && [[ $(tput colors) -ge 8 ]]; then
    RD=$(tput setaf 1); GR=$(tput setaf 2) YL=$(tput setaf 3) RS=$(tput sgr0)
fi

echo -e "\nStarting ${SERVICE_NAME} deployment..."

# check if docker is installed and up/running
# yum install docker-io for CentOS 6.x
command -v docker > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "docker is not installed"
    exit 1
fi
# should use service command for CentoOS 6.x and systemctl for CentoOS 7.x
# to check docker status. make it simple use docker images instead
docker images >/dev/null 2>&1
if [ $? -ne 0 ]; then
    # backdoor but doesn't survive docker restart
    # sudo chmod 666 /var/run/docker.sock
    echo -e "\nEither the docker daemon is not running or you don't have permission to connect to docker"
    echo -e "On Linux use following commands to grant $USER access to docker"
    echo -e "sudo groupadd docker; sudo usermod -aG docker $USER"
    echo -e "After the problem is fixed you can redeploy ${SERVICE_NAME}\n"
    exit 1
fi

# check if the same version ${SERVICE_NAME} is already installed
docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ | grep -q ${SERVICE_NAME}-${VERS}
if [ $? -eq 0 ]; then
    echo -e "\n${SERVICE_NAME}-${VERS} has already been deployed."
    echo -e "If you want to redeploy please run stopService.sh and deleteLocalDockerImage.sh first\n"
    exit 1
fi

# setup installation and configuration directories
if [ "$(uname)" != 'Darwin' ]; then
        # The following variable finds the location in which the self-extracting file is located by
        #  changing directories, and then printing the realpath it was invoked under
        MKSELF_LOCATION=$(cd ${USER_PWD} && dirname $(realpath $(ps -o args= $PPID | awk '{print $2}')))
        INSTDIR=${MKSELF_LOCATION}/${SERVICE_NAME}-${VERS}
else
        INSTDIR=/clickfox/${SERVICE_NAME}-${VERS}
fi
mkdir -p $INSTDIR
if [ $? -ne 0 ]; then
    echo "It is recommended to install ${SERVICE_NAME} in /clickfox directory"
    echo "You can enter ctl-c to stop the installation and fix above problem or input a different directory"
    echo "Please input the full directory name without ${SERVICE_NAME}-${VERS}"
    read -p "e.g. /home/cf ($HOME) : " INSTDIR
    if [ "$INSTDIR" = "" ]; then
        INSTDIR=$HOME
    fi
    INSTDIR=$INSTDIR/${SERVICE_NAME}-${VERS}
    mkdir -p $INSTDIR || exit 1
fi
# Configuraiton is based on service not service with versions
# For Mac by default only files in /Users/, /Volumes/, /private/, and /tmp
# can be shared directly using -v bind mount.
if [ "$(uname)" != 'Darwin' ]; then
    CONFDIR=${INSTDIR%/*}/${SERVICE_NAME}_conf
else
    CONFDIR=${HOME}/${SERVICE_NAME}_conf
fi
mkdir -p $CONFDIR || exit 1

echo -e "Installation dir: ${GR}${INSTDIR}${RS}"
echo -e "Configuration dir: ${GR}${CONFDIR}${RS}"

# deploy admin scripts to correct directory
mkdir -p ${INSTDIR}/bin
chmod 755 ${INSTDIR}
/bin/rm -f ${INSTDIR}/bin/* > /dev/null 2>&1
/bin/cp -r bin ${INSTDIR}/
chmod -R 755 ${INSTDIR}/bin
chmod 755 ${CONFDIR}/

# Auto-migrate the services.conf file if needed
/bin/cp -nr conf/* ${CONFDIR}/
# Force the copy of the services.conf.tmpl file (it may have changed)
/bin/cp -f conf/services.conf.tmpl ${CONFDIR}/
${INSTDIR}/bin/config.sh migrate

echo "Loading docker image..."
docker load --input ${SERVICE_NAME}DockerImg.tar
if [ $? -ne 0 ]; then
    echo -e "\nLoading ${SERVICE_NAME} docker image failed\n"
    exit 1
fi

echo -e "\n${SERVICE_NAME} successfully deployed"
echo -e "The service start and stop scripts are in ${GR}${INSTDIR}/bin${RS} directory\n"

echo -e "${SERVICE_NAME} is not started."
echo -e "Run ${GR}${INSTDIR}/bin/start.sh or stop.sh${RS} to start/stop the servicen"
echo -e "Run ${GR}${INSTDIR}/bin/config.sh${RS} to configure routing rules"
echo -e "Run ${GR}${INSTDIR}/bin/reload.sh${RS} to reload httpd config changes\n"

