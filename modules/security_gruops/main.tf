resource "aws_security_group" "sg_proxy" {
    name = "sg_proxy"
    description = "grupo de seguridad para el svr proxy"
    vpc_id = var.vpc_id

    ingress {
        description = "SSH desde IP admin"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.cidr_admin]
    }
    ingress {
        description = "UI proxy"
        from_port   = 81
        to_port     = 81
        protocol    = "tcp"
        cidr_blocks = [var.cidr_admin]
    }

    ingress {
        description = "port http"
        from_port = 80
        to_port   = 80
        protocol  = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "port https"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Project     = "polaris_etl"
        ManagedBy   = "Terraform"
        Environment = "prob"
        Name = "proxy"
    }
}

resource "aws_security_group" "sg_airflow" {
    name = "sg_airflow"
    description = "grupo de seguridad para el svr airlfow"
    vpc_id = var.vpc_id

    ingress {
        description = "SSH desde el svr proxy"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [aws_security_group.sg_proxy.id]
    }
    ingress {
        description = "ui airflow"
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        security_groups = [aws_security_group.sg_proxy.id]
        }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Project     = "polaris_etl"
        ManagedBy   = "Terraform"
        Environment = "prob"
        Name = "airflow"
    }
}

resource "aws_security_group" "sg_celery" {
    name = "sg_celery"
    description =  "grupo de seguridad para el svr celery"
    vpc_id = var.vpc_id

    ingress {
        description = "port para el svr proxy"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [aws_security_group.sg_proxy.id]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Project     = "polaris_etl"
        ManagedBy   = "Terraform"
        Environment = "prob"
        Name = "celery"
    }
}

resource "aws_security_group" "sg_rabbitMQ" {
    name = "sg_rabbitMQ"
    description = "grupo de seguridad para el svr rabbitMQ"
    vpc_id =  var.vpc_id

    ingress {
        description = "port para el svr proxy"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [aws_security_group.sg_proxy.id]
    }
    ingress {
        description = "port para el svr airflow"
        from_port = 5672
        to_port = 5672
        protocol = "tcp"
        security_groups = [aws_security_group.sg_airflow.id]
    }

    ingress {
        description = "port para el svr celery"
        from_port = 5672
        to_port = 5672
        protocol = "tcp"
        security_groups = [aws_security_group.sg_celery.id]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Project     = "polaris_etl"
        ManagedBy   = "Terraform"
        Environment = "prob"
        Name = "rabbitmq"
    }
}

resource "aws_security_group" "sg_db" {
    name = "sg_db"
    description = "grupo de seguridad para el svr db"
    vpc_id = var.vpc_id

    ingress {
        description = "port para el svr proxy"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [aws_security_group.sg_proxy.id]
    }
    ingress {
        description = "port para el svr celery"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        security_groups = [aws_security_group.sg_celery.id]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Project     = "polaris_etl"
        ManagedBy   = "Terraform"
        Environment = "prob"
        Name = "db"
    }
}