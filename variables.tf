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

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

# variable "subnet_prefix" {
#   description = "The address prefix to use for the subnet."
#   default     = "10.0.10.0/24"
# }

variable "subnets" {
  description = "List of subnets with CIDR blocks"
  type        = map(string)
  default     = {
    subnet1 = "10.0.1.0/24"
    subnet2 = "10.0.2.0/24"
    subnet3 = "10.0.3.0/24"
  }
}
