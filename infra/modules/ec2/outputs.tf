# modules/ec2/outputs.tf
output "instance_id" {
  value = aws_instance.website_server.id
}

output "public_ip" {
  value = aws_instance.website_server.public_ip
}