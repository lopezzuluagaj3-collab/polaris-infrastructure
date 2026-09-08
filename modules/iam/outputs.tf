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
