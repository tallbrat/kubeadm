module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.1"

  name       = "kubeadm-demo"
  cidr       = "10.10.0.0/16"
  azs        = ["us-east-1a"]
  create_vpc = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnets = ["10.10.1.0/24"]
}

locals {
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "control_node_sg" {
  name        = "control_node_sg"
  description = "Allow all the control node components"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 10248
    to_port     = 10260
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
  }
  tags = {
    Name = "control_node"
  }
}

resource "aws_security_group" "weave_net" {
  name   = "weave_net_sg"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 6783
    to_port     = 6784
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6783
    to_port     = 6783
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
  }
  tags = {
    Name = "weave net"
  }
}

resource "aws_security_group" "worker_node_sg" {
  name        = "worker_node_sg"
  description = "Allow all the worker node components"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 10256
    to_port     = 10256
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
  }
  tags = {
    Name = "worker_node"
  }
}

resource "aws_instance" "control_node" {
  ami                         = "ami-04e5276ebb8451442"
  instance_type               = "t2.medium"
  subnet_id                   = module.vpc.public_subnets[0]
  key_name                    = "wsl-env-test"
  vpc_security_group_ids      = [aws_security_group.control_node_sg.id, aws_security_group.weave_net.id]
  depends_on                  = [aws_security_group.weave_net, aws_security_group.control_node_sg]
  associate_public_ip_address = true

  tags = {
    name = "control_node"
  }
}

resource "aws_instance" "worker_node" {
  count                  = 2
  ami                    = "ami-04e5276ebb8451442"
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.public_subnets[0]
  key_name               = "wsl-env-test"
  vpc_security_group_ids = [aws_security_group.worker_node_sg.id, aws_security_group.weave_net.id]
  depends_on             = [aws_security_group.weave_net, aws_security_group.worker_node_sg]
  associate_public_ip_address = true
  tags = {
    name = "worker_node_${count.index + 1}"
  }

}