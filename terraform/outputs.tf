output "vpc_id" {
  description = "JobTrack VPC ID"
  value       = aws_vpc.jobtrack.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.jobtrack.address
}

