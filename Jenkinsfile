pipeline {
	options {
		// Number of Jenkins builds to keep
		buildDiscarder(logRotator(numToKeepStr: '10'))
	}
	tools {
		maven 'maven 3.5.4'
		jdk 'jdk8u181'
	}
	environment {
		ARTIFACTORY_ID = '1338225831@1414737651573'
		SLACK_CHANNEL = 'builds'
		// CD_HOSTS can be a '&' delimited series of hostnames for which deployments should be triggered (environment section doesn't support arrays), e.g.
		// CD_HOSTS = '192.168.16.156 - Hood Host&192.168.16.191 - qa-dolphin-master-1 - Paired with atx-cdh-3, atx-qa-cdh-4 and atx-qa-cdh-9 (Multi-tenant)'
		CD_HOSTS = '192.168.16.191 - qa-dolphin-master-1 - Paired with atx-cdh-3, atx-qa-cdh-4 and atx-qa-cdh-9 (Multi-tenant)'
		SERVICE_NAME = 'ProxyService'
		// Initial version can be set here, but final version must include branch information
		VERSION = sh(returnStdout: true, script: "grep '\"version\":' version.json | awk '{print \$NF}' | sed 's/[\",]//g'").trim()
	}
	agent {
		node {
		   label 'docker-builder'
		   customWorkspace '/home/ubuntu/jam/docker-builder/workspace'
		}

	}
	stages {
		// If the branch is not master, perform certain cleanup tasks
		stage('branch-tasks') {
			when {
				not {
					branch 'master'
				}
			}
			steps {
				// Set the number of build to keep in artifactory to 1. Will only push to artifactory if the build is successful, so 1 successful build should always exist
				rtBuildInfo(
						maxBuilds: 1,
						deleteBuildArtifacts: true
						)
				script {
					// Since this version is not being set in the environmental variables, it's not the version available to "makePackage.sh"
					VERSION = "${VERSION}-${BRANCH_NAME}"
				}
			}
		}
		stage('build') {
			steps {
				sh 'echo Building ${BRANCH_NAME}...'
				sh './scripts/makePackage.sh'
				script {
					// Can't use a separate environment variable for the tags, since Jenkins doesn't define empty string variables
					// Have to set properties here, since the VERSION isn't known until after branch-tasks have run
					ARTIFACT_PROPS = "branch=${BRANCH_NAME};service=${SERVICE_NAME};version=${VERSION};${sh(returnStdout: true, script: "git tag --contains | sed 's/^/tags=/' | tr '\n' ';'").trim()}"
				}
			}
		}
	}
	post {
		success {
			// Upload the artifacts to artifactory
			rtUpload(
					serverId: "${ARTIFACTORY_ID}",
					spec:
					"""{
					"files": [{
					"pattern": "target/*.sh",
					"props": "${ARTIFACT_PROPS}",
					"target": "fox-tars-local/com/clickfox-services/",
					"recursive": "false"
					}]
					}"""
				)
			// Publish the build info for the aforementioned artifact
			rtPublishBuildInfo(
					serverId: "${ARTIFACTORY_ID}"
					)
			script {
				if (env.BRANCH_NAME == 'master') {
					// If master branch, run a deployment job for each dolphin host listed in CD_HOSTS
					/*CD_HOSTS.tokenize('&').each {
						echo "Deploying master branch to '${it}'"
						build job: 'deployDolphin', wait: false, parameters: [[$class: 'StringParameterValue', name: SERVICE_NAME, value: 'refs/heads/master'], [$class: 'StringParameterValue', name: 'Host', value: it]]
					}*/
				}
			}
		}
		fixed {
			// Send slack message if builds are now good
			slackSend color: "good", message: "Job: ${env.JOB_NAME} build ${env.BUILD_NUMBER} is now good", channel: "${SLACK_CHANNEL}"
		}
		failure {
			slackSend color: "danger", message: "Job: ${env.JOB_NAME} build ${env.BUILD_NUMBER} has failed (<${env.BUILD_URL}|Open>)", channel: "${SLACK_CHANNEL}"
		}
	}
}
