# ProxyService
Configure Apache HTTP Server as Dolphin reverse proxy server
## Build ProxyService package 

Run scripts/makePackage.sh to build a self-extractable package ProxyService-\${VERSION}-\${BUILD_NUMBER}.sh

```
$ ./scripts/makePackage.sh
```
* ProxyService-\${VERSION}-${BUILD_NUMBER}.sh will be created in target directory
* This is the final product for Docker deployment
## How to deploy the ProxyService to a Docker Host

Download the ProxyService-\${VERSION}-${BUILD_NUMBER}.sh file to the Docker host. Run it and follow the prompts.
```sh
$ chmod ProxyService-${VERSION}-${BUILD_NUMBER}.sh
$ ./ProxyService-${VERSION}-${BUILD_NUMBER}.sh
e.g.
$ ./ProxyService-2.0.0-12.sh
```
##How to start/stop/delete the ProxyService
Change the working directory to the installation directory
* start the service
```sh
$ ./bin/start.sh
```
* stop the service
```sh
$ ./bin/stop.sh
```
* delete local Docker image
```sh
$ ./bin/deleteLocalDockerImage.sh
```
## How to configure the ProxyService
The configuration directory ProxyService_conf is one level above the installation directory ProxyService-\${VERSION}-\${BUILD_NUMBER}

Change the working directory to the installation directory and run followin script to configure the ProxyService
```sh
$ ./bin/config.sh
Usage: ./bin/config.sh add|del ServiceName ServiceHostIp Path Port
  e.g. ./bin/config.sh add ConfigService 192.168.16.229 config 8888
```
## How to branch, modify, and update the ProxyService and its version
1) Branch the ProxyService project. This is a safe operation since the makePackage.sh will automatically append the branch name to the ProxyService .sh file even if it does a build on your branch. 
2) Update the version.json file number on your branch to the NEXT version. If it was 2.1.0, change it to 2.2.0 for example. Commit and push this change to git on your branch too.
3) Develop your changes, test, code review on branch as normal.
4) When ready to merge your branch back to master, merge master back to your branch first. Make sure no one else released ProxyService on master in case you need to bump the version number up again. Do the merge back to master from your branch. The new version will build in Jenkins.
