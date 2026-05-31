locals {
  public_instance_placements = flatten([
    for subnet_index, subnet in aws_subnet.public : [
      for instance_index in range(var.ec2_instances_per_subnet) : {
        instance_index = instance_index
        subnet_index   = subnet_index
        subnet_id      = subnet.id
      }
    ]
  ])

  private_instance_placements = flatten([
    for subnet_index, subnet in aws_subnet.private : [
      for instance_index in range(var.ec2_instances_per_subnet) : {
        instance_index = instance_index
        subnet_index   = subnet_index
        subnet_id      = subnet.id
      }
    ]
  ])
}

data "aws_ami" "ubuntu_jammy" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "public_ec2" {
  name        = "public-ec2-sg"
  description = "Allow SSH and HTTP access to public demo EC2 instances."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_public_ingress_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_public_ingress_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-ec2-sg"
  }
}

resource "aws_security_group" "private_ec2" {
  name        = "private-ec2-sg"
  description = "Allow VPC-internal access to private demo EC2 instances."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "VPC internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-ec2-sg"
  }
}

resource "aws_instance" "public" {
  count = length(local.public_instance_placements)

  ami                         = data.aws_ami.ubuntu_jammy.id
  instance_type               = var.ec2_instance_type
  key_name                    = var.ec2_key_name
  subnet_id                   = local.public_instance_placements[count.index].subnet_id
  vpc_security_group_ids      = [aws_security_group.public_ec2.id]
  associate_public_ip_address = true

  tags = {
    Name   = "public-subnet-${local.public_instance_placements[count.index].subnet_index + 1}-ec2-${local.public_instance_placements[count.index].instance_index + 1}"
    Tier   = "public"
    Subnet = "public-subnet-${local.public_instance_placements[count.index].subnet_index + 1}"
  }
}

resource "aws_instance" "private" {
  count = length(local.private_instance_placements)

  ami                         = data.aws_ami.ubuntu_jammy.id
  instance_type               = var.ec2_instance_type
  key_name                    = var.ec2_key_name
  subnet_id                   = local.private_instance_placements[count.index].subnet_id
  vpc_security_group_ids      = [aws_security_group.private_ec2.id]
  associate_public_ip_address = false

  tags = {
    Name   = "private-subnet-${local.private_instance_placements[count.index].subnet_index + 1}-ec2-${local.private_instance_placements[count.index].instance_index + 1}"
    Tier   = "private"
    Subnet = "private-subnet-${local.private_instance_placements[count.index].subnet_index + 1}"
  }
}
