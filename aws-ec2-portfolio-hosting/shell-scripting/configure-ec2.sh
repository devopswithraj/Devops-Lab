#! /bin/bash

# configure ec2 instance to run nginx server
# create 3 ec2 machine and configure ssh key to access the machine
# ssh-keygen -t rsa -b 2048  -C "akhiles@livingdevops.com"

# for server in $(cat servers.txt)
# do
# ssh -qT ec2-user@$server hostname
# done

# for server in $(cat servers.txt)
# do
# ssh -qT ec2-user@$server <<EOF
# touch a.txt
# ls ; date; uptime ; hostname
# EOF
# done

# i=1
# for server in $(cat servers.txt)
# do
# scp html/server$i.html ec2-user@$server:/home/ec2-user/
# ssh -qT ec2-user@$server <<EOF

# # install nginx
# sudo yum install nginx -y
# sudo systemctl enable nginx
# sudo mv /home/ec2-user/server$i.html /usr/share/nginx/html/index.html
# sudo systemctl start nginx

# EOF

# i=$((i+1))
# done



for server in $(cat servers.txt)
do
ssh -qT ec2-user@$server <<EOF
# cleaup nginx
sudo systemctl stop nginx
sudo systemctl disable nginx
sudo yum remove nginx -y
EOF

i=$((i+1))
done