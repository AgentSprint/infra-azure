# Inbound: block VNet → Core (overrides default allow)
resource "azurerm_network_security_rule" "core_deny_vnet_in" {
  name                        = "deny-vnet-to-core"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = var.subnets["core"]
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["core"].name
}

# Inbound (optional): allow Jump → Core for admin
resource "azurerm_network_security_rule" "core_allow_jump_admin" {
  name                        = "allow-jump-admin-to-core"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = var.subnets["jump"]
  destination_address_prefix  = var.subnets["core"]
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389", "5986"]
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["core"].name
}

# Outbound: allow HTTPS to Internet (GitHub, registries)
resource "azurerm_network_security_rule" "core_allow_https_internet" {
  name                        = "allow-core-https-to-internet"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = var.subnets["core"]
  destination_address_prefix  = "Internet"
  source_port_range           = "*"
  destination_port_range      = "443"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["core"].name
}

# Outbound: allow Azure control plane & data plane
resource "azurerm_network_security_rule" "core_allow_azure_services" {
  name                        = "allow-core-to-azure-services"
  priority                    = 121
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_address_prefix       = var.subnets["core"]
  destination_address_prefix  = "AzureCloud"
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["core"].name
}

# Outbound: default deny (tighten after allows above)
resource "azurerm_network_security_rule" "core_deny_all_out" {
  name                        = "deny-core-all-outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = var.subnets["core"]
  destination_address_prefix  = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["core"].name
}


# Inbound: allow only Admin CIDRs
resource "azurerm_network_security_rule" "jump_allow_admin_in" {
  for_each                    = toset(var.admin_cidrs)
  name                        = "allow-admin-any-to-jump"
  priority                    = 100 + index(tolist(toset(var.admin_cidrs)), each.key)
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = each.value
  destination_address_prefix  = var.subnets["jump"]
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389", "5986"]
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["jump"].name
}

# Inbound: deny everything else
resource "azurerm_network_security_rule" "jump_deny_rest_in" {
  name                        = "deny-jump-all-inbound"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = var.subnets["jump"]
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["jump"].name
}

# Outbound: allow mgmt to Agent
resource "azurerm_network_security_rule" "jump_allow_to_agent" {
  name                        = "allow-jump-to-agent-mgmt"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = var.subnets["jump"]
  destination_address_prefix  = var.subnets["agent"]
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389", "5986"]
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["jump"].name
}

# Outbound: allow HTTPS to Internet (updates)
resource "azurerm_network_security_rule" "jump_allow_https_internet" {
  name                        = "allow-jump-https-to-internet"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = var.subnets["jump"]
  destination_address_prefix  = "Internet"
  source_port_range           = "*"
  destination_port_range      = "443"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["jump"].name
}

# Outbound: deny everything else
resource "azurerm_network_security_rule" "jump_deny_all_out" {
  name                        = "deny-jump-all-outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = var.subnets["jump"]
  destination_address_prefix  = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["jump"].name
}

# Inbound: deny agent ↔ agent (east-west)
resource "azurerm_network_security_rule" "agent_deny_east_west" {
  name                        = "deny-agent-east-west"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = var.subnets["agent"]
  destination_address_prefix  = var.subnets["agent"]
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["agent"].name
}

# Inbound: deny VNet → Agent (override default allow)
resource "azurerm_network_security_rule" "agent_deny_vnet_in" {
  name                        = "deny-vnet-to-agent"
  priority                    = 105
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = var.subnets["agent"]
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["agent"].name
}

# Inbound: allow Jump → Agent (SSH/RDP/WinRM)
resource "azurerm_network_security_rule" "agent_allow_jump_mgmt" {
  name                        = "allow-jump-to-agent-mgmt"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = var.subnets["jump"]
  destination_address_prefix  = var.subnets["agent"]
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389", "5986"]
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["agent"].name
}

# Outbound: allow 80/443 to Internet (egress via NAT Gateway)
resource "azurerm_network_security_rule" "agent_allow_web_out" {
  name                        = "allow-agent-web-out"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = var.subnets["agent"]
  destination_address_prefix  = "Internet"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["agent"].name
}

# Outbound: allow Azure services (if agents use MSI/KeyVault/Storage/Logs)
resource "azurerm_network_security_rule" "agent_allow_azure_services" {
  name                        = "allow-agent-to-azure-services"
  priority                    = 121
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_address_prefix       = var.subnets["agent"]
  destination_address_prefix  = "AzureCloud"
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["agent"].name
}

# Outbound: deny everything else
resource "azurerm_network_security_rule" "agent_deny_all_out" {
  name                        = "deny-agent-all-outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_address_prefix       = var.subnets["agent"]
  destination_address_prefix  = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.nsg["agent"].name
}
