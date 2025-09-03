# AgentSprint Runner Platform — Master Architecture Reference

**Purpose**: This document is the single source of truth for the AgentSprint architecture. It captures every decision, component, function, and service discussed. Use this if the chat or laptop is lost — it contains the full blueprint.

**Version**: v1.0 (2025-09-03 IST)

---

## 1. High-Level Objectives

* Provide secure, cost-optimized GitHub runner infrastructure per client.
* Ensure agents (ephemeral Spot VMs) run in isolated subnets with no public IPs.
* Decouple webhook ingestion using Azure Function + Service Bus.
* Provide secure admin access using ephemeral Spot jump hosts (no Bastion, budget constraint).
* Allow controlled outbound Internet (pip install, apt, GitHub API) via NAT Gateway.
* Implement daily working hours (08:00–20:00 IST) schedule to stop/deallocate resources at night.
* Support Spot eviction notifications and graceful cleanup.
* Maintain runtime configuration centrally, accessible by all components.

---


## 2. Resource Group Layout (per client)

**Per client RGs** (3 total):
* `rg-<client_code>-core`     → VNet, subnets, NAT GW, NSGs, AgentSprint main VM
* `rg-<client_code>-jump`     → Jump hosts (ephemeral)
* `rg-<client_code>-agent`    → Agent runner VMs (ephemeral)

---

## 3. Components Inventory

### Per client (`rg-<client_code>-core`)

* **Service Bus (Standard)**
  * Namespace: `sb-agentsprint`
  * Queues: `webhook-events`, `agent-events`
* **Key Vault**: `kv-agentsprint`
  * Secrets: `github-webhook-secret`, `github-app-private-key`
* **Cosmos DB (serverless)**
  * DB: `agentsprint`, container: `configs` (PK `/client_code`)
* **Storage Account**: `stagentsprint`
  * Container: `webhook-payloads` (optional raw webhook payloads)
* **Log Analytics Workspace**: `log-agentsprint`
* **Azure Function App (Python)**: `func-agentsprint`
  * `/webhook/github`: GitHub webhook ingress → Service Bus
  * `/jump/create` + `/jump/delete`: manage Spot jump hosts
  * Timers: TTL cleanup, daily schedule (08:00 start, 20:00 stop)

* **Core RG** (`rg-<client_code>-core`)
  * VNet: `vnet-<client_code>`
  * Subnets: `subnet-<code>-core`, `subnet-<code>-jump`, `subnet-<code>-agent`
  * NAT Gateway: `ngw-<code>` with PIP `pip-nat-<code>`
  * NSGs: `nsg-<code>-core`, `nsg-<code>-jump`, `nsg-<code>-agent`
  * Main VM: `vm-<code>-core-as`
    * Private only (no PIP)
    * Runs AgentSprint app, consumes Service Bus queues
    * Uses system-assigned MI
* **Jump RG** (`rg-<client_code>-jump`)

  * Ephemeral Spot Jump Hosts created/deleted by Function
  * Temp PIP, NSG rules restricted to admin CIDRs, JIT enabled
* **Agent RG** (`rg-<client_code>-agent`)

  * Ephemeral Spot Agent VMs (no PIP)
  * Outbound only via NAT GW
  * Each runs eviction watcher → publishes to Service Bus
  * User-assigned MI: `uami-agent-events-sender`

---

## 4. Detailed Functions & Services

### Azure Function App

* **Webhook handler**

  * Endpoint: `/webhook/github`
  * Validates `X-Hub-Signature-256` HMAC with secret from KV
  * Restrict inbound to GitHub IP ranges
  * Publishes compact message to `webhook-events`
  * Optional: raw payload saved to Blob
* **Jump lifecycle**

  * Endpoints: `/jump/create`, `/jump/delete`
  * Creates/deletes Spot VM in jump subnet
  * Assigns temp Standard PIP
  * Adds NSG rule for admin CIDR ports (22/3389/5986)
  * Optional: Defender JIT for time-boxed access
  * Tags with `expires_at`
* **Timers**

  * TTL cleanup: every 10–15 min, remove expired jumps
  * Daily schedule: 08:00 IST start (VM start, NAT attach); 20:00 IST stop (VM deallocate, optional NAT delete)

### Main VM (AgentSprint)

* Consumes messages from Service Bus queues

  * `webhook-events`: orchestrates GitHub + Azure actions
  * `agent-events`: responds to agent eviction (deregister, reschedule)
* Outbound Internet: via NAT GW (stable PIP recommended)
* Reads config from Cosmos DB; secrets from Key Vault
* No inbound public IP

### Agent VMs (Ephemeral Runners)

* Spot VMs, created/destroyed by AgentSprint
* Subnet: `subnet-<code>-agent`
* No public IPs, outbound only (80/443 via NAT)
* Explicit NSG deny for agent↔agent traffic
* Each runs **eviction watcher**:

  * Polls IMDS scheduled events
  * On `Preempt`, publishes to `agent-events` (via UAMI)

### Jump Hosts (Ephemeral)

* Spot VMs created via Function in `subnet-<code>-jump`
* Temporary PIP assigned
* NSG restricts inbound to admin CIDRs, ports 22/3389/5986
* Deleted manually or via TTL cleanup

### Shared services

* **Service Bus**: event backbone (decouples workloads)
* **Cosmos DB**: runtime config (shared by Function + Main VM)
* **Key Vault**: all secrets (webhook secret, GH App private key)
* **Storage**: optional raw payload archive
* **Log Analytics**: logs, flow logs, metrics

---

## 5. Scheduling

* Work hours: 08:00–20:00 IST (per client)
* At 20:00 IST:

  * Pause consumer (flag in Cosmos)
  * Deallocate main VM (preferred over delete)
  * Optional: delete NAT GW to save hourly cost (retain Standard PIP for stable IP)
* At 08:00 IST:

  * Recreate NAT GW if deleted; attach PIP
  * Start main VM
  * Resume consumer

---

## 6. Security Model

* **NSG rules**

  * Core: outbound 443 allowed, inbound denied (except optional jump mgmt)
  * Jump: inbound only from admin CIDRs (22/3389/5986), outbound to agents
  * Agent: inbound deny agent↔agent, inbound allow jump→agent, outbound 80/443 only
* **Identities**

  * Function MI: SB Sender, KV Secrets User, Cosmos Contributor, VM/Network Contributor
  * Main VM MI: SB Receiver, KV Secrets User, Cosmos Contributor, VM/Network Contributor
  * Agent UAMI: SB Sender (to `agent-events` only)
* **Secrets**: never on disk, always in Key Vault
* **Bastion**: excluded (budget); replaced with Spot jump hosts

---

## 7. Config Store (Cosmos DB)

* Container: `configs`, PK: `/client_code`
* Document example:

```json
{
  "id": "client-<code>",
  "client_code": "<code>",
  "network": {
    "vnet_name": "vnet-<code>",
    "subnets": {"core": "10.x.1.0/24", "jump": "10.x.2.0/24", "agent": "10.x.3.0/24"},
    "nat": {"enabled": true, "attach_to_core": true, "retain_public_ip": true},
    "admin_cidrs": ["203.0.113.12/32"]
  },
  "scheduling": {
    "timezone": "Asia/Kolkata",
    "work_window": {"start": "08:00", "end": "20:00"},
    "night_actions": {"main_vm": "deallocate", "nat_gateway": "delete", "retain_pip": true}
  },
  "jump_defaults": {"os": "linux", "spot": true, "ttl_minutes": 120},
  "agent_policy": {"deny_east_west": true, "egress_ports": [80, 443]},
  "webhook": {"queue_name": "webhook-events", "kv_ref_secret": "kv://github-webhook-secret"},
  "github_app": {"app_id": 123456, "kv_ref_private_key": "kv://gh-app-private-key"}
}
```

* Updates use **ETags**; Change Feed can trigger `config-updated` events

---

## 8. GitHub Integration

* **GitHub App** (recommended over PATs)

  * Webhook URL: Azure Function `/webhook/github`
  * Events: `workflow_job`, `check_run`, `push`, `pull_request`
  * Permissions: PRs, Issues, Checks, Actions
  * Secrets: App ID, private key in Key Vault
* **Outbound allowlist**: stable egress PIP from NAT for external systems

---

## 9. Reliability & Observability

* **Service Bus**: duplicate detection, DLQ alerts, sessions optional
* **Consumers**: idempotency via delivery GUIDs
* **Eviction handling**: 30s notice → eviction watcher publishes event
* **Logs/metrics**: Functions, SB queues, VM logs, NSG flow logs, NAT SNAT usage
* **Alerts**: Function 5xx, SB DLQ > 0, queue age threshold, NAT SNAT > 80%, failed logons

---

## 10. Naming & Tags

* RGs: `rg-<code>-core|jump|agent`
* VNet: `vnet-<code>`
* Subnets: `subnet-<code>-core|jump|agent`
* NSGs: `nsg-<code>-core|jump|agent`
* NAT: `ngw-<code>`, `pip-nat-<code>`
* VMs: `vm-<code>-core-as`, `vm-<code>-jump-<os>-<seq>`, `vm-<code>-agent-<seq>`
* Identities: `uami-agent-events-sender`
* Tags: `client=<code>`, `env=prod|nonprod`, `owner=agentsprint`, `role=core|jump|agent|network`, `expires_at=<UTC>`

---

## 11. Frozen Decisions

* ❌ No Azure Bastion; ✅ Spot jump hosts with temp PIP + JIT
* ✅ Webhooks ingress via Function → Service Bus; main VM is private-only
* ✅ Agents: Spot, no PIPs, outbound via NAT, eviction watcher → SB
* ✅ NAT GW attached to agent (mandatory), recommended to core (stable egress)
* ✅ Daily schedule: VM deallocate at 20:00 IST, start at 08:00 IST; NAT optionally deleted (retain PIP)
* ✅ Config in Cosmos DB; secrets in Key Vault

---



## Event Flow: GitHub to AgentSprint Main VM

GitHub Webhooks ──HTTPS──> Azure Function (HTTP trigger)
               │  (HMAC verify)
               ▼
            Azure Service Bus (Queue or Topic)
               ▼
           AgentSprint (main VM) — Consumer
             (private-only, no inbound PIP)
               ├─ GitHub API calls (outbound 443)
               └─ Azure SDK calls (Managed Identity)

**End of Master Reference v1.0**
