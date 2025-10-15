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


variable "msk_username1" {
  description = "Username for MSK SCRAM authentication"
  type        = string
  default     = "testuser1"
}

variable "msk_password1" {
  description = "Password for MSK SCRAM authentication"
  type        = string
  sensitive   = true
  # No default - this must be provided for security
}

variable "msk_username2" {
  description = "Username for MSK SCRAM authentication"
  type        = string
  default     = "testuser2"
}

variable "msk_password2" {
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
