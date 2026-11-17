variable "region" {
  type = string
}

variable "db_name" {
  type = string
}

variable "env" {
  type = string
}

variable "project" {
  type = string
}

variable "vehicle-images-code-version" {
  type    = string
  default = "1"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public Subnet CIDR values"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private Subnet CIDR values"
}

variable "database_subnets" {
  type        = list(string)
  description = "Database Subnet CIDR values"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
}

variable "alarm_email" {
  type        = string
  description = "Email address for CloudWatch alarm notifications"
  default     = "madmaxcloudonline@gmail.com"
}
