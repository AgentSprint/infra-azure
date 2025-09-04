variable "client_code" {
    description     = "client code for resource naming"
    type            = string
}

variable "location" {
    description     = "client azure location"
    type            = string
    default         = "Central India"
}

variable "vnet_ip_address_space"{
    description     = "vnet ip address space"
    type            = string
}

variable "subnets" {
  description = "Map of subnet names to address prefixes"
  type        = map(string)
}

variable "base_groups" {
  type = list(string)
  description = "List of base groups"
}

variable "admin_cidrs" {
  type = list(string)
  description = "List of admin cidrs"
}