variable "name" {
  description = "Name prefix for the VPC and its resources."
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of Availability Zones to create subnets in."
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for the private subnets (one per AZ)."
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for the public subnets (one per AZ)."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to all VPC resources."
  type        = map(string)
  default     = {}
}