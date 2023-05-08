provider "aws" {
  region = "us-east-1"
  access_key = "AKIAW3AF7IU4Y4MUPSKJ"
  secret_key = "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"
}
# 1. Create a vpc
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Prod-VPC"
  }
}
# 2. Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}
# 3. Create Custom Route Table 
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Prod RT"
  }
}
# 4. Create a subnet

resource "aws_subnet" "subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Prod Subnet"
  }
}
# 5. Associate subnet with Route Table
resource "aws_route_table_association" "connection-RT-subnet" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route-table.id
}
# 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "sg" {
  name        = "security_group"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 2
    to_port          = 2
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "security_group"
  }
}
# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.sg.id]
}
# 8. Assign an elastic IP to the network interface created in stept 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.igw]
}
# 9. Create intance for Ubuntu server and install/enable apache2
resource "aws_instance" "server-instance" {
  ami = "ami-007855ac798b5175e"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
# 10. Commands to install the appache server
  user_data = <<-EOF
             #!/bin/bash
             sudo apt update -y
             sudo apt install apache2 -y
             sudo systemctl start apache2
             sodu bash -C 'echo your very first web server > /var/www/html/index/htm'
             EOF
  tags = {
      Name = "my-web-server"
  }
}

add line