# terraform.tfvars

client_code = "tcs"

location = "Central India"

vnet_ip_address_space = "10.1.0.0/16"

subnets = {
  core  = "10.1.0.0/26"    # 64 IPs (10.1.0.0 - 10.1.0.63)
  jump  = "10.1.0.64/26"   # next 64 IPs (10.1.0.64 - 10.1.0.127)
  agent = "10.1.1.0/24"    # 256 IPs (10.1.1.0 - 10.1.1.255)
}

base_groups = ["core", "jump", "agent"]

admin_cidrs = ["*"]