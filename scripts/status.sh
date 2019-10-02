#!/bin/bash

# Colors
if [[ -t 1 ]] && [[ -n $(tput colors) ]] && [[ $(tput colors) -ge 8 ]]; then
    RD=$(tput setaf 1); GR=$(tput setaf 2) YL=$(tput setaf 3) RS=$(tput sgr0)
fi

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd ${SCRIPTDIR}/..

docker images >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "\nEither the docker daemon is not running or you don't have permission to connect to docker\n"
    exit 1
fi

# STATUS
# The status filter matches containers by status. You can filter using
# created, restarting, running, removing, paused, exited and dead.
# For example, to filter for running containers:
# docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ --filter status=running

# Follow Linux init script status
# http://refspecs.linuxbase.org/LSB_3.0.0/LSB-PDA/LSB-PDA/iniscrptact.html
if [ $(docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ --filter status=created | wc -l) -eq 2 ]; then
    echo "created"
    exit 7
elif [ $(docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ --filter status=restarting | wc -l) -eq 2 ]; then
    echo "restarting"
    exit 1
elif [ $(docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ --filter status=running | wc -l) -eq 2 ]; then
    echo "running"
    exit 0
elif [ $(docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ --filter status=removing | wc -l) -eq 2 ]; then
    echo "removing"
    exit 7
elif [ $(docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ --filter status=paused | wc -l) -eq 2 ]; then
    echo "paused"
    exit 7
elif [ $(docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ --filter status=exited | wc -l) -eq 2 ]; then
    echo "exited"
    exit 7
elif [ $(docker ps -a --no-trunc --filter name=^/${SERVICE_NAME}-${VERS}$ --filter status=dead | wc -l) -eq 2 ]; then
    echo "dead"
    exit 1
else
    # Add our own status here
    # The container does not exist
    echo "removed"
    exit 5
fi

