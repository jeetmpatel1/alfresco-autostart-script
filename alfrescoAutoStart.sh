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

## get top 10 errors encounters and email it
sendErrorIfAny()
{
	## wait 5 second before sending email
	sleep 5
	errors= grep -i -C 1 'ERROR\|SEVERE' $catalinaPath | awk '{print $0,"\n"}'  | mail -s "Autoscript:: Host "$(hostname)" started with mentioned ERROR information" $mailTO
}

startOsBasedApache()
{
	if [ $major_version == 6 ]
	then
		logger "you are using redhat "$major_version" so starting using /usr/sbin/apachectl start"
		$httpdStartPath start
	elif [ $major_version == 7 ]
	then
		logger "you are using redhat "$major_version" so starting using sudo /usr/sbin/apachectl start"
		sudo $httpdStartPath start
		haltForSeconds 10
	else
		logger "script not able to get OS version and hence not able to judge the way to start apachectl "
		#echo -e "$httpdFailMsg"| mail -s "AutoScript:: Process either 'LLAWP' or 'httpd' failed to start for Host "$(hostname)""  $mailTO
	fi
}

## LOGGER
logger()
{
	stamp=$(date "+%Y-%m-%d_%H%M")
	printf "$stamp %s\n" "$*" >> "$Logfile"
}
## Validate OS version
#function RHELVersion()
#{
#	rpm -q --queryformat '%{RELEASE}' rpm | grep -o [[:digit:]]*\$
#}

haltForSeconds()
{
	logger "halt for "$1" seconds inititated"
	sleep $1
}


if isClamdRunning && isMountOK
then
				logger "Process 'clamd' success"
				logger "Mount is success"
				
				if isTomcatRunning
				then
							### This phase will validate that tomcat process is running but alfresco having some issue being up or any error are there
							### So based on curl response we will validate process running on port 8080 will make sense or not
							logger "tomcat process appear to be running, now validating via curl"
							logger "value of curlUrlAlfresco is  $curlUrlAlfresco"
							if [ $curlUrlAlfresco == 200 ]
							then
									logger "Curl alfresco validates application alfresco with response code 200"
									logger "now checking httpd process"
									
									validateHttpdService
									
									logger "Attempt for httpd service check completed, script exited"
									#echo -e "$alfrescoSuccessStartCurlMsg" | mail -s "AutoScript:: Curl validation successfull on Host "$(hostname)" and app server runs fine." $mailTO
																	
									logger "#### now checking actual running alfresco and expected alfresco"
									
									logger "Found tomcat already running with alfresco ->" $actualAlfrescoRunning
									if [ "$actualAlfrescoRunning" != "$expectedAlfrescoProcess" ]
									then
											logger "Defined alfresco version and actual version running are different please cross check manually and stop current running alfresco , Script exited with no further action - triggering email"
											echo -e "$emailBodyOtherAlfrescoProcessDetected" | mail -s "AutoScript:: Other alfresco already running on Host "$(hostname)" with different version please validate manually" $mailTO
											exit
									else
											logger "expected alfresco "$actualAlfrescoRunning  " running"
											logger "validate if httpd(LLAWP) running or not"
											if isLLAWPRunning
											then
												#logger "detected LLAWP is OFF"
												validateHttpdService
												logger "Attempt to start service 'httpd' done"
												exit
											else
												logger "Detected LLAWP(httpd) service already running"
												logger "Script execution ends & no action to take"
												exit
											fi
									fi	
											
							else
									logger "Curl alfresco validated and responded with code "$curlUrlAlfresco" so there is some issue and application is not up successfully"
									logger "please validate host "$(hostname)" manually for reason, script exited"
									echo -e "$alfrescoFailStartCurlMsg" | mail -s "AutoScript:: Curl validation failed on Host "$(hostname)" please validate manually" $mailTO
								    exit
							fi
							
							
						
				else

						logger "Alfresco process not running so, Alfresco tomcat need to start ...."
						logger "proceed to rename catalina.out log file"
						
						renameCatalina
						
						logger "catalina.out renamed successfully."
						logger "Initiate Starting alfresco.."
						
						##########  ALFRESCO 4 START ########################
						#$alfresco4StartPath/startup.sh start
						######################################################
						
						##########  ALFRESCO 5 START ########################
						$alfrescoHomePath/alfresco.sh start
						######################################################
						
						logger "Reading log to find if server startup successful or not"
			
						#tail -f $catalinaPath | while read LINE
						#do
						#[[ "${LINE}" == *"Server startup"* ]] && break
						#echo "$LINE"
						#done
						logger "Initiate reading log file catalina.out"
						   tail -n0 -F $catalinaPath | while read line; 
						   do
								if echo $line | grep -q 'Server startup' ; 
								then
									pkill -9 -P $$ tail > /dev/null 2>&1
									break
								fi
							done
											
						logger "Initial alfresco start post halt or pause for few seconds"
						haltForSeconds 5
												
						if isTomcatRunning
						then
						   	   logger "Initial tomcat start happen properly, now validating httpd .."
							   
							   validateHttpdService
							   haltForSeconds 5
							   						   
							   logger "Alfresco tomcat server started successfully. triggering success email"
							   echo -e "$alfrescoStartedMsg" | mail -s "AutoScript:: Alfresco just started successfully for Host"$(hostname)""  $mailTO
							   haltForSeconds 5
							   logger "Sending error information via email"
							   sendErrorIfAny
							   logger "script execution completed successfully."
							   exit
						else
							logger "Initial tomcat start did not happen properly.."
							echo -e "$alfrescoStartFailedMsg" | mail -s "AutoScript:: Script failed to start Tomcat App on Host "$(hostname)""  $mailTO
						fi	
						
						
				fi
			
		
else
		logger "'clamd' or 'mount' Failed - sending Email"
		logger "Process 'clamd' and necessary 'mount' Failed - executing email action"
		echo "clamd or mount failed for host "$(hostname)" ..  sending email"
		echo -e "$emailBodyClamdMountFail" | mail -s "AutoScript:: Process either 'clamd' or 'mount' failed for Host "$(hostname)""  $mailTO
fi
 