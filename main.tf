terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "sirius-terraform-state-022784797877"
    key     = "airflow/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

module "networking"{
    source = "./modules/networking"

    cidr_vpc = "12.0.0.0/16"
    cidr_privada = "12.0.2.0/24"
    cidr_publica = "12.0.1.0/24"
    az           = data.aws_availability_zones.available.names[0]
    environment  = "prod"
    owner        = "juan"
}

module "security_gruops" {
    source = "./modules/security_gruops"

    vpc_id = module.networking.vpc_id
    cidr_admin = var.allowed_cidr
    vpc_cidr = "10.0.0.0/16"
}

module "compute" {
  source = "./modules/compute"
  ami                  = data.aws_ami.ubuntu.id
  subnet_publica_id    = module.networking.subnet_publica_id
  subnet_privada_id    = module.networking.subnet_privada_id
  sg_proxy_id          = module.security_gruops.sg_proxy_id
  sg_airflow_id        = module.security_gruops.sg_airflow_id
  sg_rabbitMQ_id       = module.security_gruops.sg_rebbitMQ
  sg_celery_id         = module.security_gruops.sg_celery_id
  sg_db_id             = module.security_gruops.sg_db_id
  key_proxy            = "proxy_key"
  key_general          = "general_key"
}