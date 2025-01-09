provider "aws" {
  region  = "us-east-1"
  access_key = ""
  secret_key = ""
}

# Create VPC

resource "aws_vpc" "prod_vpc" {
  cidr_block       = "10.0.0.0/16"
  
   tags = {
    Name = "production"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id

}

# Create Egress-Only Internet Gateway
resource "aws_egress_only_internet_gateway" "ipv6_gateway" {
  vpc_id = aws_vpc.prod_vpc.id
}
# Create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod_vpc.id

  # Route for IPv4 traffic
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  # Route for IPv6 traffic
  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}
# Create a subnet

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
    Name = "prod-subnet"
  }
}
# Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
# Create security group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod_vpc.id

ingress {
  description = "HTTPS"
  cidr_blocks = ["0.0.0.0/0"]
  from_port         = 443
  protocol       = "tcp"
  to_port           = 443
}

ingress {
  description = "HTTP"
  cidr_blocks = ["0.0.0.0/0"]
  from_port         = 80
  protocol       = "tcp"
  to_port           = 80
}

ingress {
  description = "SSH"
  cidr_blocks = ["0.0.0.0/0"]
  from_port         = 22
  protocol       = "tcp"
  to_port           = 22
}

egress {
  cidr_blocks = ["0.0.0.0/0"]
  from_port         = 0
  protocol       = "-1"
  to_port           = 0
}

tags = {
  Name = "allow_web"
 } 
}
# Create a network interface with an IP in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}
# Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}
# Create an Ubuntu server and install/enable Apache 2

resource "aws_instance" "web_server_instance" {
  ami           = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-keypairs"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
 
   user_data = <<-EOF
  #!/bin/bash
  sudo apt-get update
  sudo apt-get install -y apache2
  sudo systemctl start apache2
  sudo bash -c 'echo "First web server" > /var/www/html/index.html'
  EOF

   tags = {
       Name = "web-server"
       
    }

}