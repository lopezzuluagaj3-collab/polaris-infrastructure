resource "aws_instance" "svr_proxy" {
  ami                         = var.ami
  instance_type               = "t3.small"
  subnet_id                   = var.subnet_publica_id
  vpc_security_group_ids      = [var.sg_proxy_id]
  key_name                    = "proxy_key"
  associate_public_ip_address = true

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size           = 32
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
}

resource "aws_instance" "svr_airflow" {
    ami = var.ami
    instance_type = "t3.small"
    subnet_id = var.subnet_privada_id
    vpc_security_group_ids = [var.sg_airflow_id]
    key_name = "general_key"
    associate_public_ip_address = false

    metadata_options {
        http_tokens   = "required"
        http_endpoint = "enabled"
    }

    root_block_device {
        volume_size           = 16
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
    }
}

resource "aws_instance" "svr_rabbitMQ" {
    ami = var.ami
    instance_type = "t3.small"
    subnet_id = var.subnet_privada_id
    vpc_security_group_ids = [var.sg_rabbitMQ_id]
    key_name = "general_key"
    associate_public_ip_address = false

    metadata_options {
        http_tokens   = "required"
        http_endpoint = "enabled"
    }

    root_block_device {
        volume_size           = 16
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
    }
}

resource "aws_instance" "svr_celery" {
    ami = var.ami
    count         = 2
    instance_type = "t3.small"
    subnet_id = var.subnet_privada_id
    vpc_security_group_ids = [var.sg_celery_id]
    key_name = "general_key"
    associate_public_ip_address = false

    metadata_options {
        http_tokens   = "required"
        http_endpoint = "enabled"
    }

    root_block_device {
        volume_size           = 16
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
    }
    tags = {

        Name = "servidor-${count.index + 1}"
    }
}

resource "aws_instance" "svr_db" {
    ami = var.ami
    instance_type = "t3.small"
    subnet_id = var.subnet_privada_id
    vpc_security_group_ids = [var.sg_db_id]
    key_name = "general_key"
    associate_public_ip_address = false

    metadata_options {
        http_tokens   = "required"
        http_endpoint = "enabled"
    }

    root_block_device {
        volume_size           = 32
        volume_type           = "gp3"
        encrypted             = true
        delete_on_termination = true
    }
}