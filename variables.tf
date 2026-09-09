variable "aws_region" {
  type        = string
  description = "Región de AWS"
}

variable "allowed_ssh_cidr" {
  description = "CIDR permitido para SSH al bastión (proxy)"
  type        = string
  default     = "0.0.0.0/0"
}