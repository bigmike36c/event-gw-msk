output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.ec2.public_ip
}

output "ssh_private_key" {
  description = "Private SSH key for EC2 access"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}

output "ssh_connection_command" {
  description = "SSH connection command"
  value       = "ssh -i ssh_key.pem ec2-user@${aws_instance.ec2.public_ip}"
}

output "ssh_key_filename" {
  description = "Filename for the SSH private key"
  value       = "ssh_key.pem"
}

output "msk_broker_endpoints" {
  description = "TLS broker endpoints for MSK"
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
}

output "scram_credentials" {
  description = "SCRAM username/password (from Secrets Manager)"
  value = {
    username = jsondecode(aws_secretsmanager_secret_version.scram_version.secret_string)["username"]
    password = jsondecode(aws_secretsmanager_secret_version.scram_version.secret_string)["password"]
  }
  sensitive = true
}
