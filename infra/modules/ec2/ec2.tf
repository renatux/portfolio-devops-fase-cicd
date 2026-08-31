resource "aws_instance" "website_server" {
  ami                    = "ami-0332d564d76dbd8d6" #Amazon Linux 2023 kernel-6.18 ami
  instance_type          = var.instance_type
  key_name               = "key-portfolio"
  vpc_security_group_ids = [aws_security_group.website_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ecr_ec2.name
  user_data              = file("${path.module}/user_data.sh")

  tags = {
    Name        = "website-server-${var.environment}"
    Provisioned = "Terraform"
    Cliente     = "portfoliozzz"
  }
}

## Security Group
resource "aws_security_group" "website_sg" {
  name   = "website-sg"
  vpc_id = "vpc-07a6e93cbfbf26de2"
  tags = {
    Name        = "website-sg"
    Provisioned = "Terraform"
    Cliente     = "portfoliozzz"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.website_sg.id
  cidr_ipv4         = "179.118.193.163/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.website_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.website_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.website_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

