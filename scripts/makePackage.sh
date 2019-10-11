#!/bin/bash

#
# This script is a template to package your service Docker image and needed 
# admin scripts to a self-extracting file.
# 
# Modify this script as needed to meet different servcie needs
#

#
# Use Makeself tool to build a self-extracting service package which
# includes docker images and admin scripts
#

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd $SCRIPTDIR/..

# Docker repository name must be lowercase
# Remote artifactory example: artifactory.clickfox.net:6555/clickfox/services/configservice
# Local Fox repository example: clickfox/services/configservice
# Local Fox2 repository example: clickfox/fox2services/configservice
SERVICE_NAME=$(git config --get remote.origin.url)
SERVICE_NAME=${SERVICE_NAME##*/}
SERVICE_NAME=${SERVICE_NAME%.git}
service_name=$(echo ${SERVICE_NAME} | tr '[:upper:]' '[:lower:]')
# VERSION and BUILD_NUMBER are Jenkins built-in environment variables
[ -z "$VERSION" ] && VERSION=2.0.0
[ -z "$BUILD_NUMBER" ] && BUILD_NUMBER=latest
# ProxyService version
VERS=${VERSION}-${BUILD_NUMBER}
# Get httpd from Docker Hub
REPO_NAME=httpd
# TAG is the Docker Hub httpd version
TAG=2.4-alpine
PORT=80

/bin/rm -rf target/dockerPkg
mkdir -p target/dockerPkg/bin

# check if docker is up and running
docker images > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Either docker is not installed or docker daemon is not up and running"
    exit 1
fi

# make sure makeself is installed
command -v makeself > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "makeself is required but not installed"
    echo "Please run \"brew install makeself\" on Mac"
    echo "or \"sudo yum install makeself\" on Linux to install makeself"
    exit 1
fi

# check if docker image exists
docker images ${REPO_NAME}:${TAG} 2>/dev/null | grep -q "${TAG}"
if [ $? -ne 0 ]; then
    echo "${REPO_NAME}:${TAG} image is not found in local registry"
    echo "Try to pull from artifactory..."
    docker pull ${REPO_NAME}:${TAG}
    if [ $? -ne 0 ]; then
        echo "${REPO_NAME}:${TAG} image is not found in artifactory"
        echo "Please run \"mvn clean install\" to build the docker image" 
        exit 1
    fi
fi
echo "Build target/dockerPkg/${SERVICE_NAME}DockerImg:${TAG}.tar image to a tar file"
docker save -o target/dockerPkg/${SERVICE_NAME}DockerImg.tar ${REPO_NAME}:${TAG}
if [ $? -ne 0 ]; then
    echo "docker save -o target/dockerPkg/${SERVICE_NAME}DockerImg.tar ${REPO_NAME}:${TAG} failed"
    exit 1
fi

# Setup service name, version, tag etc.
for i in scripts/*.sh
do
    sed "/\${TAG}/s/\${TAG}/${TAG}/g;
         /\${SERVICE_NAME}/s/\${SERVICE_NAME}/${SERVICE_NAME}/g;
         /\${REPO_NAME}/s/\${REPO_NAME}/${REPO_NAME//\//\\/}/g;
         /\${VERS}/s/\${VERS}/${VERS}/g
         /\${PORT}/s/\${PORT}/${PORT}/g
        " \
    $i > target/dockerPkg/bin/${i#scripts/}
done

# Don't bundle makePackage.sh
/bin/rm target/dockerPkg/bin/makePackage.sh
# deployDocker.sh is the script to load docker image and install admin scripts
# on target machine. Move it from bin directory
/bin/mv target/dockerPkg/bin/deployDocker.sh target/dockerPkg/

find target/dockerPkg -name "*.sh" -exec chmod 755 {} \;
/bin/cp -r conf target/dockerPkg/

# build self-extractable ${REPO_NAME} package
# without compression
# makeself --nocomp target/dockerPkg/ ${SERVICE_NAME}-${VERS}.sh "${SERVICE_NAME}" ./deployDocker.sh
# use default compression tool gzip
echo "Make package ${SERVICE_NAME}-${VERS}.sh" 
makeself target/dockerPkg/ target/${SERVICE_NAME}-${VERS}.sh "${SERVICE_NAME}" ./deployDocker.sh || exit 1

echo -e "\nYou can run ${SERVICE_NAME}-${VERS}.sh on any host to deploy ${SERVICE_NAME}\n"
echo -e "$0 successfully finished"
