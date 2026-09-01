variable "cidr_vpc" {
  description = "CIDR block de la VPC "
  type        = string

}

variable "cidr_publica" {
  description = "CIDR block de la subnet pública"
  type        = string
}

variable "cidr_privada" {
  description = "CIDR block de la subnet privada"
  type        = string
}

variable "az" {
  description = "Availability Zone"
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