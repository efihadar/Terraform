provider "aws" { 
    region     = "eu-central-1"
    access_key = "AKIAZNTBQYU2V2GNOF2Q"
    secret_key = "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"
}

#1 Create vpc

resource "aws_vpc" "website_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "website-vpc"
    }
}

#2 Create Internet GateWay

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.website_vpc.id
}

#3 Create Custom Route Table

resource "aws_route_table" "website_route_table" {
    vpc_id = aws_vpc.website_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

  tags = {
      Name = "Prod"
  }
}

#4 Create a Subnet

resource "aws_subnet" "subnet-1" {
    vpc_id            = aws_vpc.website_vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "eu-central-1a"

  tags = {
    Name = "ProdWebsite_subnet"
  }
}

#5 Associate subnet with Route Table

resource "aws_route_table_association" "a" {
    subnet_id       = aws_subnet.subnet-1.id
    route_table_id  = aws_route_table.website_route_table.id
    
}

#6 Create Security Group
resource "aws_security_group" "website-sg" {
    name        = "website-sg_traffic"
    description = "Allow web inbound traffic"
    vpc_id      = aws_vpc.website_vpc.id

    ingress {
        description = "HTTPS"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTP"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = 0
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    tags = {
        Name = "allow_tls"
    }
}
#7 Create Network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "website_nic" {
    subnet_id       = aws_subnet.subnet-1.id
    private_ips     = ["10.0.1.50"]
    security_groups = [aws_security_group.website-sg.id]

}

#8 Assign an Elastic IP to the network interface created in step 7 

resource "aws_eip" "website_eip" {
    vpc                       = true
    network_interface         = aws_network_interface.website_nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on                = [aws_security_group.website-sg]

}

#9 Create Ubuntu server and install/anable apache2

resource "aws_instance" "website_instance" {
    ami               = "ami-0b1deee75235aa4bb"
    instance_type     = "t2.micro"
    availability_zone = "eu-central-1a"
    key_name          = "terraformwebsite"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.website_nic.id
    }
      
    user_data = <<-EOF
                #! /bin/bash
                sudo apt-get update
                sudo apt install -y apache2
                sudo systemctl start apache2
                sudo systemctl enable apache2
                echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
                EOF
    tags = {
        Name = "Terraform-webserver"
    }
}

output "server_public_ip" {
    value = aws_eip.website_eip.public_ip
}

output "server_privet_ip" {
  value = aws_instance.website_instance.private_ip
}

output "server_id" {
  value = aws_instance.website_instance.id
}