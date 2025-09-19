# Event Gateway MSK Infrastructure

A Terraform configuration for deploying a complete Kafka testing environment on AWS with MSK (Managed Streaming for Kafka), EC2 instance, and Docker Compose setup.

**⚠️ IMPORTANT: Please tear down resources after use to avoid unnecessary costs!**

## What This Deploys

- **VPC** with 3 public subnets across different AZs
- **MSK Cluster** (3 brokers) with TLS + SCRAM authentication
- **EC2 Instance** with Docker, Docker Compose, and kafkactl pre-installed. Files for KNEP deployment automatically cloned from this repository's `knep-deployment/` directory to the EC2 instance
- **Security Groups** configured for proper access
- **Secrets Manager** for SCRAM credentials

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.4.0
- **IMPORTANT**: Select a region with available VPC capacity (AWS limit: 5 VPCs per region)

### Configuration (Required Before Deployment)

**⚠️ Deployment will fail without proper configuration!**

1. **Copy the example configuration:**

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. **Edit terraform.tfvars with your values:**

```hcl
# AWS Configuration
aws_profile = "your-aws-profile-name"
aws_region  = "us-west-2"
ami_id      = "ami-0d67ba0437fec367a"  # Amazon Linux 2023 us-west-2

# Network Access (OPTIONAL - Leave empty to disable SSH access)
ssh_access_ip = "YOUR_PUBLIC_IP/32"  # Find with: curl ifconfig.me

# MSK Authentication (REQUIRED - Choose secure credentials)
msk_username = "your-username"
msk_password = "your-secure-password"

# Resource Names
cluster_name  = "your-cluster-name"
instance_name = "your-instance-name"
secret_name   = "AmazonMSK_your-secret-name"
```

3. **Find your public IP:**

```bash
curl ifconfig.me
```

### Deploy Infrastructure

**⏱️ Expected deployment time: 15-20 minutes**

```bash
terraform init
terraform plan
terraform apply
```

### Connect to EC2 Instance

**Using AWS Session Manager:**

1. Go to AWS Console → EC2 → Instances
2. Select your instance → Connect → Session Manager
3. **Important:** Switch to ec2-user: `sudo su - ec2-user`
4. Navigate to config: `cd /home/ec2-user/event-gw-msk/knep-deployment`

**Using SSH (if key pair configured):**

```bash
ssh ec2-user@<EC2_PUBLIC_IP>
```

### Configure Your Services

Before running your services, you need to configure the application-specific settings:

1. **Configure kafkactl with MSK credentials:**

```bash
# Edit the kafkactl configuration
nano .kafkactl.yml
```

Update the `username` and `password` fields with your SCRAM credentials. You can get these values by running `terraform output scram_credentials` from your local machine.

2. **Set up environment variables:**

```bash
# Copy the example environment file
cp knep.env.example knep.env

# Edit with your specific values
nano knep.env
```

Update the environment variables with your specific configuration values.

### Run Your Services

**Note:** The EC2 instance automatically clones this repository and sparse-checks out the `knep-deployment/` directory containing your Docker Compose and kafkactl configuration files.

```bash
# Start Docker Compose services
docker-compose up -d

# Check status
docker-compose ps
```

### Konnect's KNEP Config

- **MSK Endpoints:** Available in Terraform outputs (`terraform output msk_broker_endpoints`)
- **SCRAM Credentials:** Available in Terraform outputs (`terraform output scram_credentials`)

## Cleanup

```bash
terraform destroy
```

## Important Notes

- **Session Manager:** Always run `sudo su - ec2-user` to access the correct user environment
- **Cost:** ~$9/day for full deployment (MSK is the main cost driver)
- **Region:** By default, deployed in us-west-2 to avoid VPC limits
