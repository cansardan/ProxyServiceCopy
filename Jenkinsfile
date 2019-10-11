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
	}
	agent {
		label 'docker-builder'
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
			}
		}
		stage('build') {
			steps {
				sh 'echo Building ${BRANCH_NAME}...'
				sh './scripts/makePackage.sh'
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
					"target": "fox-tars-local/com/clickfox-services/",
					"recursive": "false"
					}]
					}"""
				)
			// Publish the build info for the aforementioned artifact
			rtPublishBuildInfo(
					serverId: "${ARTIFACTORY_ID}"
					)
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
