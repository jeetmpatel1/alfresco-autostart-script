# Alfresco Auto Start Script 

[Alfresco](https://www.alfresco.com/) is a Content Management System written in JAVA. Alfresco runs in application containers like [Tomcat](http://tomcat.apache.org/). Linux servers or Database frequently goes under patching. When you have multiple Alfresco repository hosted on different linux instances,it is tedious task to start application manually once patching is completed. This repository automates the task of starting the application server. 




# Installation

This is just bash script. It doesn't require any kind of installation.

# Services

This script is written considering the below services

- [Tomcat](http://tomcat.apache.org/): application server on which Alfresco is running
- [Apache httpd](https://httpd.apache.org/): A webserver that is connected to Tomcat via AJP
- [Clamd](https://linux.die.net/man/8/clamd): A daemon listens for incoming connections on Unix and/or TCP socket and scans files or directories on demand.
- [curl](https://linux.die.net/man/1/curl): To make http request to validate the running/down servers
- [Siteminder-LLAWP](https://www.siteminder.com/): A daemon listens every authentication requests for Siteminder integration. 

## Notes

Script assumes alfresco is installed and it's storage is mounted to /alfresco/alf20. 