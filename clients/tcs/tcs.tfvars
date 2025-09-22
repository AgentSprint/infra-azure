# terraform.tfvars

client_code = "tcs"

location = "Central India"

vnet_ip_address_space = "10.10.0.0/16"

subnets = {
  core  = "10.10.1.0/24"    # 64 IPs (10.1.0.0 - 10.1.0.63)
  jump  = "10.10.2.0/24"   # next 64 IPs (10.1.0.64 - 10.1.0.127)
  agent = "10.10.3.0/24"    # 256 IPs (10.1.1.0 - 10.1.1.255)
  privatelink = "10.10.4.0/24"    # 256 IPs (10.1.1.0 - 10.1.1.255)
}

subnet_func_ip = "10.10.5.0/24"

base_groups = ["core", "jump", "agent"]

admin_cidrs = ["*"]