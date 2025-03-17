terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-00bb6a80f01f03502"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.TF_SG.id]
  key_name      = "TF-key"

  root_block_device {
    volume_type = "gp3"
    volume_size = 9
  }

  tags = {
    Name = "ExampleAppServerInstance"
  }
}

resource "aws_security_group" "TF_SG" {
  name        = "unique-security-group-name"  # Updated to a unique name
  description = "Security group created using Terraform"
  vpc_id      = "vpc-03ea81600f5e44bb6"

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "TF_SG"
  }
}

resource "local_file" "inventory" {
  filename = "ansible/inventory.ini"
  content  = <<-EOT
    [server]
    ${aws_instance.app_server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/pranav/Downloads/TF-key.pem
  EOT
}

output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}