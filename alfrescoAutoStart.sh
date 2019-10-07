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

isTomcatRunning()
{
	netstat -tupln | grep 8080 > $tmp_netstat
	more $tmp_netstat | awk '{print $7}'  | cut -c1-5
	if [[ -s $tmp_netstat ]]
	then
		return 0
	else
		#remove file
		rm $tmp_netstat
		return 1
	fi  

}

## function to validate if mount is mapped,this should be changed across host
isMountOK()
{
   logger "mount to check "$MOUNTVALUE
   if grep -qs $MOUNTVALUE /proc/mounts; then
		return 0
	else
		return 1
	fi
}
## function to rename catalina.out on every restart
renameCatalina()
{
   file_name=$alfrescoHomePath/tomcat/logs/catalina.out
   stamp=$(date "+%Y-%m-%d_%H%M%S")
   new_filename=$file_name.$stamp
   mv $file_name $new_filename
}
## get alfresco version running