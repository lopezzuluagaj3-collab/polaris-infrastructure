output "sg_proxy_id" {
  description = "ID del security group del proxy"
  value       = aws_security_group.sg_proxy.id
}

output "sg_airflow_id" {
  description = "ID del security group del svr airflow"
  value       = aws_security_group.sg_airflow.id
}

output "sg_rebbitMQ" {
  description = "ID del security group de svr rabbitQM"
  value       = aws_security_group.sg_rabbitMQ.id
}

output "sg_celery_id" {
  description = "ID del security group de celery"
  value       = aws_security_group.sg_celery.id
}

output "sg_db_id" {
  description = "ID del security group de DB"
  value       = aws_security_group.sg_db.id
}


