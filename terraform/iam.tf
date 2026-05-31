# =============================================================================
# IAM Configuration for EC2 Instances
# =============================================================================
# Designed by: Security & Compliance Lead
# Purpose: Give our EC2 instances the minimum permissions they need to:
#   1. Send logs and metrics to CloudWatch
#   2. Read/write GPS data files in S3
#   3. Be accessed securely via Systems Manager (instead of SSH)
#
# Principle followed: Least Privilege
#   Each role gets ONLY the permissions it really needs. Nothing more.
# =============================================================================


# -----------------------------------------------------------------------------
# IAM Role for EC2 instances
# -----------------------------------------------------------------------------
# This role is "assumed by" EC2. When we attach this role to an EC2 instance,
# the instance can make AWS API calls without needing static credentials
# stored on the server.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name        = "fleet-ec2-role"
  description = "Role attached to fleet EC2 instances for CloudWatch, S3, and SSM access."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "fleet-ec2-role"
  }
}


# -----------------------------------------------------------------------------
# Attach AWS-managed policy: CloudWatchAgentServerPolicy
# -----------------------------------------------------------------------------
# This managed policy lets the EC2 instance:
#   - Send metrics to CloudWatch
#   - Send logs to CloudWatch Logs
# We use the AWS-managed version (instead of writing our own) because
# AWS keeps it up to date when CloudWatch adds new features.
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


# -----------------------------------------------------------------------------
# Attach AWS-managed policy: AmazonSSMManagedInstanceCore
# -----------------------------------------------------------------------------
# This managed policy lets us connect to the EC2 instance using
# AWS Systems Manager Session Manager. This is a SAFER replacement for SSH:
#   - No need to open port 22 to the internet
#   - No need to manage SSH keys
#   - All session activity is logged in CloudTrail
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# -----------------------------------------------------------------------------
# Custom policy: limited S3 access to our fleet data bucket only
# -----------------------------------------------------------------------------
# This is a CUSTOM policy (not AWS-managed) because we want to be very
# specific. We do NOT want to give "all S3 access". We only give access
# to our project bucket, and only the actions we need.
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "s3_fleet_data_access" {
  name        = "fleet-s3-data-access"
  description = "Allow EC2 instances to read and write objects in the fleet data S3 bucket only."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow listing the bucket (so the app can see what files exist)
        Sid    = "ListFleetBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.fleet_data.arn
        ]
      },
      {
        # Allow read and write on objects INSIDE the bucket only
        # We do NOT allow s3:DeleteBucket or other dangerous actions
        Sid    = "ReadWriteFleetObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.fleet_data.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "fleet-s3-data-access"
  }
}


# -----------------------------------------------------------------------------
# Attach the custom S3 policy to our role
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_fleet_data_access.arn
}


# -----------------------------------------------------------------------------
# Instance Profile
# -----------------------------------------------------------------------------
# An IAM role cannot be attached to an EC2 instance directly. We have to
# wrap the role in an "instance profile" first, then attach the instance
# profile to the EC2 resource. This is just how AWS works.
# -----------------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "fleet-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "fleet-ec2-instance-profile"
  }
}


# -----------------------------------------------------------------------------
# Outputs (so other .tf files can reference these)
# -----------------------------------------------------------------------------
output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile. Attach this to aws_instance resources."
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role."
  value       = aws_iam_role.ec2_role.arn
}
