# NSG Rule Book for AgentSprint Platform

This document describes the detailed Network Security Group (NSG) rules for each subnet in the AgentSprint architecture. It serves as both a human-readable reference and a mapping to the Terraform implementation in `nsg_rules.tf`.

---

## Core Subnet (Azure Function, Service Bus client, AgentSprint main VM)

### Inbound
- ✅ (Optional) Allow mgmt from Jump → Core (22/3389/5986)
- ❌ Deny all other VNet → Core inbound (overrides default AllowVnetInBound)

### Outbound
- ✅ Allow Tcp:443 to Internet (GitHub, package registries, etc.)
- ✅ Allow * to AzureCloud (control plane APIs) (service tag only; Storage, KeyVault, etc. not supported as NSG service tags)
- ❌ Deny all other outbound

---

## Jump Subnet (Linux & Windows jump hosts)

### Inbound
- ✅ Allow Admin CIDRs → Jump on 22 (SSH), 3389 (RDP), 5986 (WinRM over HTTPS)
- ❌ Deny all other inbound (including from VNet)

### Outbound
- ✅ Allow Jump → Agent on 22/3389/5986 only
- ✅ Allow Tcp:443 to Internet (updates/agents)
- ❌ Deny all other outbound

---

## Agent Subnet (ephemeral runners; no public IP; NAT Gateway for egress)

### Inbound
- ❌ Deny Agent ↔ Agent east-west (same subnet)
- ❌ Deny VNet → Agent (blocks default AllowVnetInBound)
- ✅ Allow Jump → Agent on 22/3389/5986 only

### Outbound
- ✅ Allow Tcp:80,443 to Internet (package repos, GitHub, etc.)
- ✅ Allow to AzureCloud (service tag only; Storage, KeyVault, Monitor not supported as NSG service tags)
- ❌ Deny all other outbound

---

## Mapping to Terraform (`nsg_rules.tf`)
- Each rule above is implemented as a `azurerm_network_security_rule` resource in `nsg_rules.tf`.
- Rule priorities and source/destination address prefixes are set to enforce the above policy.
- Service tag AzureCloud is used for outbound rules to Azure services. Storage, KeyVault, etc. are not supported as NSG service tags.
- Admin CIDRs should be defined in your tfvars for jump host access.

---

**This rule book is the authoritative reference for NSG configuration in AgentSprint.**
