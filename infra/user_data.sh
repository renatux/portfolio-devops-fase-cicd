#!/bin/bash
set -euo pipefail
yum update -y
yum install -y docker unzip
usermod -aG docker ec2-user
systemctl enable --now docker
curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
unzip -qo /tmp/awscliv2.zip -d /tmp/awscli-install
/tmp/awscli-install/aws/install
rm -rf /tmp/awscliv2.zip /tmp/awscli-install