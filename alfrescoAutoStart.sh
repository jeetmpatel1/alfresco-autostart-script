#!/bin/sh
## Purpose of this script is for restart alfresco tomcat and apache httpd (LLAWP) process after patching
## 
## NOTE :: Need to change value based on environment you used mentioned in "ENVIRONMENT SPECIFIC CHANGES"

## HOST SPECIFIC CHANGES

#Location where alfresco is installed
alfrescoHomePath=/opt/alfresco-installation/alfresco-5.2.1

#Mount point of Alfresco 
MOUNTVALUE=/nas/alf20


## VARIABLES
DATE=$(date +%Y-%m-%d_%H%M)

#Alfresco v4 needs to be started via tomcat/bin/startup.sh.  Alfresco v5 can be started with startup.sh provided with installation.
alfresco4StartPath=$alfrescoHomePath/tomcat/bin

#Alfresco is running on java. There might be different Java processes being executed on RHEL. We need to find particular one in order to start/stop alfresco.
expectedAlfrescoProcess=$alfrescoHomePath/java/bin/java

#Logging path of Alfresco
catalinaPath=$alfrescoHomePath/tomcat/logs/catalina.out

#Apache httpd service command
httpdStartPath=/usr/sbin/apachectl

#Alfresco ships with two web application. 1. Alfresco Content Server. 2. Alfresco Share . Once server is up, we will send a curl request to check whether server is properly up or not. 
curlUrlAlfresco=$(curl -sL -w "%{http_code}" "localhost:8080/alfresco" -o /dev/null)
curlUrlShare=$(curl -sL -w "%{http_code}" "localhost:8080/share" -o /dev/null)

tmp_netstat=/home/alfresco/autoscript/netstat_output


## This script execution will be logged at LogDir in Logfile mentioned below.
LogDir="/home/alfresco/autoscript"
Logfile=$LogDir/autoscript_$DATE.log

## Getting RedHat OS version 6 or 7. Clamd has issues specific to RHEL7. That's why we need this.
major_version=$(rpm -q --queryformat '%{RELEASE}' rpm | grep -o [[:digit:]]*\$)
actualAlfrescoRunning=$(ps -elf | grep java | grep /tomcat/bin | awk '{print $15}')

## Mail related properties
mailTO="jeet.mpatel1@gmail.com,jmpatel@scu.edu"
emailBodyClamdMountFail="FYI\nProcess either 'clamd' or necessary 'mount' failed for host "$(hostname)".\nPlease validate with unix team and take necessary actions,script execution exited with no further action." 
emailBodyOtherAlfrescoProcessDetected="FYI\n\nScript detected that for host "$(hostname)" defined alfresco version and actual running alfresco are different, please cross check manually and perform appropriate actions\n,Script exited with no further action."
httpdFailMsg="FYI\n\nScript from host "$(hostname)" detected that it is not able to up 'LLAWP' or 'httpd' properly, please validate manually\n,Script exited with no further action."
alfrescoStartedMsg="FYI\n\nAlfresco application for host "$(hostname)" initial started with LLAWP (apache httpd) process.\nThis is script generated email please do not reply back.\n\nAny error message you received while starting alfresco will be there in subsequent email please validate from your end."
alfrescoStartFailedMsg="FYI\n\nAlfresco application for host "$(hostname)" failed to start please validate host alfresco manually."
alfrescoFailStartCurlMsg="FYI\n\nAlfresco application for host "$(hostname)" started but application failed to get response, please validate host manually."
alfrescoSuccessStartCurlMsg="FYI\n\nAlfresco application for host "$(hostname)" started successfully, validated via curl."
isLLAWPRunning()
{
	SERVICE='LLAWP'
	if ps ax | grep $SERVICE | grep -v grep > /dev/null
	then
	   return 0
	else
	   return 1
	fi
}

isClamdRunning()
{
	SERVICE='clamd'
	if ps ax | grep $SERVICE | grep -v grep  > /dev/null
	then
	   return 0
	else
	   return 1
	fi
}