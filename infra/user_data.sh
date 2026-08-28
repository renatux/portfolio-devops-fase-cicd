sudo su -
yum update -y
yum install -y docker
usermod -aG docker ec2-user && systemctl start docker


