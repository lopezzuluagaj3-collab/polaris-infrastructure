variable "role_name" {
  description = "Nombre del rol IAM que asumirán las instancias EC2"
  type        = string
  default     = "k8s-worker-node-role"
}

variable "instance_profile_name" {
  description = "Nombre del instance profile IAM asociado al rol"
  type        = string
  default     = "k8s-worker-node-profile"
}

variable "policy_name" {
  description = "Nombre de la policy IAM adjunta al rol"
  type        = string
  default     = "ebs-csi-driver-policy"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner del proyecto"
  type        = string
  default     = "juan"
}

variable "user_name" {
  description = "Nombre del usuario IAM que consume los recursos"
  type        = string
  default     = "ebs-csi-driver-user"
}
