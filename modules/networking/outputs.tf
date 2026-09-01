output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.vpc_main.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = aws_vpc.vpc_main.cidr_block
}

output "subnet_publica_id" {
  description = "ID de la subnet pública"
  value       = aws_subnet.subnet_public.id
}

output "subnet_publica_cidr" {
  description = "CIDR de la subnet pública"
  value       = aws_subnet.subnet_public.cidr_block
}

output "subnet_privada_id" {
  description = "ID de la subnet privada"
  value       = aws_subnet.subnet_private.id
}

output "subnet_privada_cidr" {
  description = "CIDR de la subnet privada"
  value       = aws_subnet.subnet_private.cidr_block
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway"
  value       = aws_nat_gateway.nat_gw.id
}