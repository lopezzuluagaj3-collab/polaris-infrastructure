resource "aws_vpc"  "vpc_main"{

    cidr_block   = var.cidr_vpc
    enable_dns_hostnames = true

    tags = {
        Terraform = "true"
        Environment = "dev"
        Name = "polaris-rt-private"
    }
    lifecycle {
      prevent_destroy = false
    }
}

resource "aws_subnet" "subnet_public" {
    vpc_id                  = aws_vpc.vpc_main.id
    cidr_block              = var.cidr_publica
    availability_zone       = var.az 
    map_public_ip_on_launch = true 

    tags = {
        Terraform = "true"
        Environment = "dev"
        Name = "polaris-subnet-publica"
    }
}

resource "aws_subnet" "subnet_private" {
    vpc_id            = aws_vpc.vpc_main.id
    cidr_block        = var.cidr_privada
    availability_zone = var.az

    tags = {
        Terraform = "true"
        Environment = "dev"
        Name = "polaris-subnet-privada"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc_main.id

    tags = {
        Terraform = "true"
        Environment = "dev"
        Name = "polaris-igw"
    }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Terraform = "true"
    Environment = "dev"
    Name = "polaris-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet_public.id

  tags = {
    Terraform = "true"
    Environment = "dev"
    Name = "polaris-nat-gw"
  }
}

resource "aws_route_table" "rt_public" {
    vpc_id = aws_vpc.vpc_main.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Terraform = "true"
        Environment = "dev"
    }  
}

resource "aws_route_table_association" "assoc_public" {
    subnet_id      = aws_subnet.subnet_public.id
    route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table" "rt_private" {
    vpc_id = aws_vpc.vpc_main.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gw.id
    }
    tags = {
        Terraform = "true"
        Environment = "dev"
    }  
}
resource "aws_route_table_association" "assoc_private" {
    subnet_id      = aws_subnet.subnet_private.id
    route_table_id =  aws_route_table.rt_private.id
}

