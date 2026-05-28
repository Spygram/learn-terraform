# output "public_vm_public_ip" {
#   description = "The public IP address of the public Ubuntu VM"
#   value       = aws_instance.public_instance.public_ip
# }

# output "private_vm_private_ip" {
#   description = "The internal private IP address of the private Ubuntu VM"
#   value       = aws_instance.private_instance.private_ip
# }

# output "public_server_ip" {
#   description = "The public ip address of the server"
#   value       = aws_instance.public_instance_server.public_ip

#}
# output "rds_endpoint" {
#   description = "The endpoint connection string for the RDS PostgreSQL database"
#   value       = aws_db_instance.postgres_db.endpoint
# }