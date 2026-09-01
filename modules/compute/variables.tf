variable "ami" {
  description = "AMI para todas las instancias EC2"
  type        = string
}

variable "subnet_publica_id" {
  description = "ID de la subnet pública (para el proxy)"
  type        = string
}

variable "subnet_privada_id" {
  description = "ID de la subnet privada (para todos los demás)"
  type        = string
}

variable "sg_proxy_id" {
  description = "ID del security group del proxy"
  type        = string
}

variable "sg_airflow_id" {
  description = "ID del security group del servidor airflow"
  type        = string
}

variable "sg_rabbitMQ_id" {
  description = "ID del security group de svr rabbitMQ"
  type        = string
}

variable "sg_celery_id" {
  description = "ID del security group de svr celery"
  type        = string
}

variable "sg_db_id" {
  description = "ID del security group de DB"
  type        = string
}

variable "key_proxy" {
  description = "Nombre del key pair para el servidor proxy"
  type        = string
}

variable "key_general" {
  description = "Nombre del key pair para los servidores privados"
  type        = string
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Responsable del proyecto"
  type        = string
  default     = "estudiante"
}