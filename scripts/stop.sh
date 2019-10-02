#!/bin/bash

# Colors
if [[ -t 1 ]] && [[ -n $(tput colors) ]] && [[ $(tput colors) -ge 8 ]]; then
    RD=$(tput setaf 1); GR=$(tput setaf 2) YL=$(tput setaf 3) RS=$(tput sgr0)
fi

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# docker update command is not available in 1.7.1
# docker update --restart=no fox_service-container
# docker inspect fox_service-${VERS}

docker images >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "\nEither the docker daemon is not running or you don't have permission to connect to docker\n"
    exit 1
fi

# Status: created, restarting, running, removing, paused, exited and dead
status=$(${SCRIPTDIR}/status.sh)
case "$status" in
    running|restarting)
        echo "Stopping ${SERVICE_NAME}-${VERS}..."
        docker stop ${SERVICE_NAME}-${VERS}
        if [ $? -ne 0 ]; then
            docker kill ${SERVICE_NAME}-${VERS}
            if [ $? -ne 0 ]; then
                echo -e "\n$0 failed\n"
                exit 1
            fi
        fi
        ;;
    *)
        echo "${SERVICE_NAME}-${VERS} is not running"
        ;;
esac

