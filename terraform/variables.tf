### NETWORKING VARIABLES
variable "vpc_cidr" {
  description = "CIDR block for the demo VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR blocks for the two public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidr) == 2
    error_message = "Exactly two public subnet CIDR blocks are required."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR blocks for the two private subnets."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]

  validation {
    condition     = length(var.private_subnet_cidr) == 2
    error_message = "Exactly two private subnet CIDR blocks are required."
  }
}

variable "ec2_instances_per_subnet" {
  description = "Number of EC2 instances to create in each public and private subnet."
  type        = number
  default     = 2
}

variable "ec2_instance_type" {
  description = "Instance type used for the demo EC2 instances."
  type        = string
  default     = "t3.micro"
}

variable "ec2_key_name" {
  description = "Optional existing EC2 key pair name for SSH access."
  type        = string
  default     = null
}

variable "allowed_public_ingress_cidr" {
  description = "CIDR block allowed to reach public EC2 instances over SSH and HTTP."
  type        = string
  default     = "0.0.0.0/0"
}

variable "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard for fleet infrastructure monitoring."
  type        = string
  default     = "fleet-infrastructure-monitoring"
}

variable "cloudwatch_metric_period" {
  description = "Metric period in seconds for EC2 CPU utilization alarms and dashboard widgets."
  type        = number
  default     = 300
}

variable "cloudwatch_cpu_alarm_threshold" {
  description = "CPU utilization percentage that triggers high CPU alarms."
  type        = number
  default     = 80
}

variable "cloudwatch_cpu_alarm_evaluation_periods" {
  description = "Number of CPU metric periods that must breach before the high CPU alarm triggers."
  type        = number
  default     = 2
}

variable "cloudwatch_status_alarm_period" {
  description = "Metric period in seconds for EC2 status check alarms."
  type        = number
  default     = 60
}

variable "cloudwatch_status_alarm_evaluation_periods" {
  description = "Number of status check periods that must breach before the status alarm triggers."
  type        = number
  default     = 2
}

variable "cloudwatch_alarm_email" {
  description = "Optional email address for CloudWatch alarm notifications. Leave null to create alarms without email actions."
  type        = string
  default     = null
}
