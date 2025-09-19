variable "aws_profile" {
  description = "AWS profile name to use for authentication"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Amazon Linux 2023)"
  type        = string
  default     = "ami-0d67ba0437fec367a" # Amazon Linux 2023 us-west-2
}

variable "ssh_access_ip" {
  description = "Your public IP address for SSH access (CIDR format, e.g., 203.0.113.1/32). Leave empty to disable SSH access."
  type        = string
  default     = ""
  validation {
    condition     = var.ssh_access_ip == "" || can(cidrhost(var.ssh_access_ip, 0))
    error_message = "ssh_access_ip must be empty or a valid CIDR block."
  }
}

variable "msk_username" {
  description = "Username for MSK SCRAM authentication"
  type        = string
  default     = "testuser"
}

variable "msk_password" {
  description = "Password for MSK SCRAM authentication"
  type        = string
  sensitive   = true
  # No default - this must be provided for security
}

variable "cluster_name" {
  description = "Name for the MSK cluster"
  type        = string
  default     = "knep-msk"
}

variable "instance_name" {
  description = "Name for the EC2 instance"
  type        = string
  default     = "knep-ec2"
}

variable "secret_name" {
  description = "Name for the Secrets Manager secret"
  type        = string
  default     = "AmazonMSK_knep-msk-user"
}
