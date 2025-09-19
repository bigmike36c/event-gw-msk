output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.ec2.public_ip
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
