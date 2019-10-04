#!/bin/bash

# Colors
if [[ -t 1 ]] && [[ -n $(tput colors) ]] && [[ $(tput colors) -ge 8 ]]; then
    RD=$(tput setaf 1); GR=$(tput setaf 2) YL=$(tput setaf 3) RS=$(tput sgr0)
fi

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

echo "Reloading httpd configuration..."

if [ "$(${SCRIPTDIR}/status.sh)" = running ]; then
    docker exec ${SERVICE_NAME}-${VERS} apachectl -k graceful
    if [ $? -ne 0 ]; then
        echo "$0 ${RD}failed${RS}"
        exit 1
    fi
else
    echo "${SERVICE_NAME}-${VERS} is not running"
fi

echo "$0 successfully finished"

