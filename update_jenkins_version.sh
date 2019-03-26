#!/bin/bash
##
# Update Jenkins WAR file 
# after saving current war file
# Created: 2019
##

## Check if New version specified or not
if [ $# -ne 1 ];
	then echo "Please specify target Jenkins WAR file version to upgrade to..."
	echo ""
	exit 1
fi

UPGDVER=$1
echo "Please stand by while we upgrade Jenkins WAR to requested version of ${UPGDVER}..."

## Get current WAR file version
CURRVER=$(java -jar /usr/share/jenkins/jenkins.war --version)

## Make a backup of current WAR file
cp /usr/share/jenkins/jenkins.war /usr/share/jenkins/jenkins.war.old_${CURRVER}
##
## Download new war version from Jenkins Download site
wget http://updates.jenkins-ci.org/download/war/${UPGDVER}/jenkins.war -O /usr/share/jenkins/jenkins.war
## Restart jenkins service to load the new WAR (twice to load the custom logo and theme as well)
#service jenkins restart
#sleep 10
#service jenkins restart

## Schedule restart of jenkins in 5 minutes
echo "Scheduled Restart of Jenkins in 2 minutues - please do not start jobs in next 2 minutes..."
echo "service jenkins restart
sleep 10
service jenkins restart" >/root/restart_jenkins.sh
chmod +x /root/restart_jenkins.sh
apt-get -y install at || true
at now + 2 min -f /root/restart_jenkins.sh

## Check new WAR version to make sure
echo "Jenkins WAR upgraded to requested version - $(java -jar /usr/share/jenkins/jenkins.war --version)"
exit 0
