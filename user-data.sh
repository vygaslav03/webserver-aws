#!/bin/bash
sudo su
yum -y install httpd
echo "<p> My WebServer!Create by Terraform </p>" >> /var/www/html/index.html
sudo systemctl enable httpd
sudo systemctl start httpd