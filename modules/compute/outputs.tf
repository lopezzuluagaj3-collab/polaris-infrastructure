output "proxy_public_ip" {
  description = "IP pública del proxy (punto de entrada SSH)"
  value       = aws_instance.svr_proxy.public_ip
}

output "celery_private_ip" {
  description = "IP privada del servidor celery"
  value       = aws_instance.svr_celery[*].private_ip
}

output "rabbitMQ_private_ip" {
  description = "IP privada del servidor RabbitMQ"
  value       = aws_instance.svr_rabbitMQ.private_ip
}

output "db_private_ip" {
  description = "IP privada de la base de datos"
  value       = aws_instance.svr_db.private_ip
}

output "airflow_private_ip" {
  description = "IP privada del servidor airflow"
  value       = aws_instance.svr_airflow.private_ip
}


output "all_instances_ids" {
  description = "Mapa de nombre a ID de instancia"
  value = {
    proxy = aws_instance.svr_proxy.id
    airflow  = aws_instance.svr_airflow.id
    rabbitMQ  = aws_instance.svr_rabbitMQ.id
    db    = aws_instance.svr_db.id
    celery = aws_instance.svr_celery[*].id
  }
}

output "all_instances_public_ips" {
  description = "Mapa de nombre a IP pública (solo proxy tendrá IP pública)"
  value = {
    proxy = aws_instance.svr_proxy.public_ip
    airflow  = aws_instance.svr_airflow.public_ip
    rabbitMQ  = aws_instance.svr_rabbitMQ.public_ip
    db    = aws_instance.svr_db.public_ip
    celery = aws_instance.svr_celery[*].public_ip
  }
}