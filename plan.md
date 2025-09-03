# AgentSprint Runner Platform — Implementation Plan

## Sequential Steps

### 1. Prepare Terraform State Backend
- Create the storage account/container for Terraform state.
- Configure the backend in your Terraform files.

### 2. Define Core Infrastructure (per client)
- Use Terraform to define:
  - Resource groups: `rg-<client_code>-core`, `rg-<client_code>-jump`, `rg-<client_code>-agent`
  - VNet and subnets (`core`, `jump`, `agent`)
  - NAT Gateway and public IP for NAT
  - NSGs for each subnet

### 3. Deploy Shared Services
- Deploy Service Bus, Key Vault, Cosmos DB, Storage, Log Analytics, and Function App using Terraform.

### 4. Implement Azure Function App
- Develop and deploy the Python Function App:
  - Webhook handler
  - Jump host lifecycle endpoints
  - Timers for cleanup and scheduling

### 5. Provision Main VM and Agent VMs
- Use Terraform to deploy the main VM (private-only, system-assigned MI).
- Define agent VM template (Spot, no public IP, user-assigned MI).
- Set up eviction watcher scripts for agent VMs.

### 6. Configure Jump Hosts
- Implement Function logic for ephemeral Spot jump hosts.
- Ensure NSG rules and JIT access are correctly set.

### 7. Set Up GitHub Integration
- Register GitHub App, configure webhook to Azure Function.
- Store secrets in Key Vault.
- Test webhook delivery and event flow.

### 8. Implement Scheduling and Automation
- Configure Function timers for daily start/stop and TTL cleanup.
- Set up Cosmos DB config documents per client.

### 9. Security Hardening
- Review NSG rules, managed identities, and Key Vault access policies.
- Test access restrictions (no public IPs for agents, jump hosts only for admin).

### 10. Monitoring & Alerts
- Configure Log Analytics, Service Bus alerts, and Function monitoring.
- Set up alerts for DLQ, SNAT usage, failed logons, etc.

### 11. Documentation & Validation
- Document all resources, flows, and operational procedures.
- Validate end-to-end: webhook → Function → Service Bus → VM → GitHub/Azure actions.

---

**Note:** The shared platform resource group has been removed as per the latest architecture decision. All shared services are now deployed as needed, without a dedicated platform RG.
