# create aws vpc 
resource "aws_vpc" "sd_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "sd_vpc"
  }
}

# create aws subnet - public
resource "aws_subnet" "sd_public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.sd_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "sd-public-subnet-${count.index + 1}"
  }
}

# create aws subnet - private
resource "aws_subnet" "sd_private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.sd_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "sd-private-subnet-${count.index + 1}"
  }
}

# create aws internet gateway
resource "aws_internet_gateway" "sd-igw" {
  vpc_id = aws_vpc.sd_vpc.id
  tags = {
    "Name" = "sd-igw"
  }
}

# create aws route table - public
resource "aws_route_table" "sd_public_route_table" {
  vpc_id = aws_vpc.sd_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sd-igw.id
  }
  tags = {
    "Name" = "sd-public-route-table"
  }
}

# create aws route table associations - public
resource "aws_route_table_association" "sd-public-route-table-association" {
  count          = 2
  subnet_id      = aws_subnet.sd_public_subnet[count.index].id
  route_table_id = aws_route_table.sd_public_route_table.id
}

# create aws route table - private
resource "aws_route_table" "sd_private_route_table" {
  vpc_id = aws_vpc.sd_vpc.id
  tags = {
    "Name" = "sd-private-route-table"
  }
}

# create aws route table associations - private
resource "aws_route_table_association" "sd-private-route-table-association" {
  count          = 2
  subnet_id      = aws_subnet.sd_private_subnet[count.index].id
  route_table_id = aws_route_table.sd_private_route_table.id
}

# create aws s3 endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.sd_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.sd_private_route_table.id,
    aws_route_table.sd_public_route_table.id
  ]

  tags = {
    "Name" = "s3-gateway-endpoint"
  }

}

# create aws security group - public
resource "aws_security_group" "sd_public_sg" {
  name        = "public-vm-sg"
  description = "allow ssh from anywhere"
  vpc_id      = aws_vpc.sd_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow http access from everywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow https access from everywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}

# create aws security group - private
resource "aws_security_group" "sd_private_sg" {
  name        = "private-vm-sg"
  description = "allow ssh from public security group"
  vpc_id      = aws_vpc.sd_vpc.id

  ingress {
    description     = "SSH from Public VM"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sd_public_sg.id]
  }

  ingress {
    description     = "allow icmp ping from public VM"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.sd_public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "private-sg"
  }
}

# create ED25519 key pair for EC2 instances using TLS provider to
# generate the key pair and AWS provider to create the key pair resource
resource "tls_private_key" "ec2-key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = tls_private_key.ec2-key.public_key_openssh

}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.ec2-key.private_key_openssh
  filename        = "${path.module}/tf-managed-key.pem"
  file_permission = "0600"
}

resource "aws_instance" "public_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.sd_public_subnet[0].id
  vpc_security_group_ids = [aws_security_group.sd_public_sg.id]
  tags = {
    "Name" = "ubuntu-public-instance"
  }
  key_name             = aws_key_pair.deployer_key.key_name
  iam_instance_profile = data.aws_iam_instance_profile.labInstanceProfile.name
  user_data            = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              EOF
}

resource "aws_instance" "public_instance_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.sd_public_subnet[0].id
  vpc_security_group_ids = [aws_security_group.sd_public_sg.id]
  tags = {
    "Name" = "ubuntu-public-server"
  }
  key_name             = aws_key_pair.deployer_key.key_name
  iam_instance_profile = data.aws_iam_instance_profile.labInstanceProfile.name
  user_data            = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              EOF
}

resource "aws_instance" "private_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.sd_private_subnet[0].id
  vpc_security_group_ids = [aws_security_group.sd_private_sg.id]
  tags = {
    "Name" = "ubuntu-private-vm"
  }
  key_name             = aws_key_pair.deployer_key.key_name
  iam_instance_profile = data.aws_iam_instance_profile.labInstanceProfile.name
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "main-rds-subnet-group"
  subnet_ids = [aws_subnet.sd_private_subnet[0].id, aws_subnet.sd_private_subnet[1].id]
  tags = {
    "Name" = "rds-private-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-postgres-sg"
  description = "Allow DB traffic from VMs"
  vpc_id      = aws_vpc.sd_vpc.id

  ingress {
    description     = "postgresql from public vm"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sd_public_sg.id]
  }

  ingress {
    description     = "postgresql from private vm"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.sd_private_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "rds-postgres-sg"
  }
}

resource "aws_db_instance" "postgres_db" {
  identifier                 = "free-tier-postgres"
  engine                     = "postgres"
  engine_version             = "18"
  auto_minor_version_upgrade = true
  instance_class             = "db.t3.micro"
  allocated_storage          = 20
  storage_type               = "gp3"

  db_name  = "postgres_db"
  username = "postgres"
  password = "secretPassw0rd"

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "free-tier-postgres-db"
  }

}