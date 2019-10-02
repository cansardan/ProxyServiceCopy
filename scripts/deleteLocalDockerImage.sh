#!/bin/bash

# Colors
if [[ -t 1 ]] && [[ -n $(tput colors) ]] && [[ $(tput colors) -ge 8 ]]; then
    RD=$(tput setaf 1); GR=$(tput setaf 2) YL=$(tput setaf 3) RS=$(tput sgr0)
fi

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [ "$1" = "-f" ]; then
    force=true
else
    force=false
fi

docker images >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "\nEither the docker daemon is not running or you don't have permission to connect to docker\n"
    exit 1
fi

# Status: created, restarting, running, removing, paused, exited and dead
status=$(${SCRIPTDIR}/status.sh)
if [ "$status" = running ]; then
    if [ $force != true ]; then
        echo "${REPO_NAME}-${VERS} is up and running"
        echo "run stop.sh to stop the service before delete the image"
        echo "or \"$0 -f\" to force stop the servcie and delete the image" 
        exit 1
    else
        # Stop the serivce before remove the image
        ${SCRIPTDIR}/stop.sh
    fi
fi

status=$(${SCRIPTDIR}/status.sh)
case "$status" in
    created|paused|exited|dead)
        echo "Remove ${SERVICE_NAME}-${VERS}..."
        docker rm ${SERVICE_NAME}-${VERS}
        if [ $? -ne 0 ]; then
            echo -e "\n$0 failed\n"
            exit 1
        fi
        ;;
    *)
        ;;
esac

docker images 2>&1 | grep "${REPO_NAME}" | grep -q "${TAG}"
if [ $? -ne 0 ]; then
    echo "${REPO_NAME}:${TAG} does not exist"
    exit 1
else
    echo "Deleting ${REPO_NAME}:${TAG} docker image..."
    docker rmi --no-prune=true ${REPO_NAME}:${TAG}
    if [ $? -ne 0 ]; then
        echo -e "\n$0 failed\n"
        exit 1
    fi
fi

# docker image command is not availabe in 1.7.1
docker image prune -f
