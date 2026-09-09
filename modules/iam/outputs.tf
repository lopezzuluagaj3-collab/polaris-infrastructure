output "instance_profile_name" {
  description = "Nombre del instance profile IAM para adjuntar a instancias EC2"
  value       = aws_iam_instance_profile.worker_node_profile.name
}

output "instance_profile_arn" {
  description = "ARN del instance profile IAM"
  value       = aws_iam_instance_profile.worker_node_profile.arn
}

output "role_arn" {
  description = "ARN del rol IAM"
  value       = aws_iam_role.worker_node_role.arn
}

output "ebs_csi_access_key_id" {
    value = aws_iam_access_key.ebs_csi_key.id
}

output "ebs_csi_secret_access_key" {
    value     = aws_iam_access_key.ebs_csi_key.secret
    sensitive = true
}