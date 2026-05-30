### NETWORKING VARIABLES
variable "vpc_cidr" {
  description = "CIDR block for the demo VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet hosting the EC2 portal."
  type        = string
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidr" {
  description = "CIDR block for the isolated private subnet."
  type        = string
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}
