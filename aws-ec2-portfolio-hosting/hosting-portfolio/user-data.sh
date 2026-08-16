#! /bin/bash

sudo yum update -y
sudo yum install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx



sudo yum install -y git
sudo yum install -y certbot python3-certbot-nginx