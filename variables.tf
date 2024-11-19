##############################################################################
# Variables File
#
# Here is where we store the default values for all the variables used in our
# Terraform code. If you create a variable with no default, the user will be
# prompted to enter it (or define it via config file or command line flags.)

variable "prefix" {
  description = "This prefix will be included in the name of most resources."
  default = "jieun"
}

variable "region" {
  description = "The region where the resources are created."
  default     = "ap-northeast-3"
}

variable "availability_zones" {
  default = ["ap-northeast-3a", "ap-northeast-3b", "ap-northeast-3c"]
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "vault_license" {
  description = "HashiCorp Vault license key"
  type        = string
  sensitive   = true
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "vpc_cidr_base" {
  default = "10.0"
}