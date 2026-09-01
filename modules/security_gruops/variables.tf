variable "vpc_id" {
  description = "ID de la VPC donde se crean los security groups"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC para reglas internas"
  type        = string
}

variable "cidr_admin" {
  type        = string
  description = "CIDR permitido en los security groups proxy"
}
