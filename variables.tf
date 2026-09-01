variable "aws_region" {
  type        = string
  description = "Región de AWS"
}

variable "allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}