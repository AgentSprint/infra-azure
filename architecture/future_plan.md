
# Scope (POC)

- **Service principal** (subscription Contributor)
- **Resource group**
- **Storage account** (for Function runtime/code)
- **Application Insights** (workspace-based)
- **Log Analytics workspace** (for AI)
- **Function App** (Python, HTTP trigger, Consumption)
- **Azure Managed Grafana**
- **Dashboard panel** (from AI logs)

---

## Azure Portal — Steps (Short)

### Service principal
- Entra ID → App registrations → New → secret → Subscriptions → IAM → Contributor to SP.

### Resource group
- `rg-<client>-core`

### Log Analytics workspace
- `law-<client>-core`

### Application Insights (workspace-based)
- `ai-<client>-core` → pick `law-<client>-core`.

### Storage account
- `st<client>funcxxxx` (Standard LRS)

### Function App (Python, HTTP trigger)
- Create → Publish Code, Python 3.10/3.11, Linux, Plan Consumption (Y1), select Storage.
- Monitoring → Application Insights: Select existing `ai-<client>-core`.

### Create function
- Function App → Functions → Add → HTTP trigger (default code is fine).
- Get Function URL.

### Test
- Hit URL in browser/curl (200 OK).
- Application Insights → Transaction search / Live Metrics to see requests.

### Azure Managed Grafana
- Create AMG.
- Data sources → Add Azure Monitor → enable Logs and select the subscription/workspace + AI.

### Dashboard panel (show executions)
- New panel → Data source: Azure Monitor / Logs → KQL:

#### Requests over time (count):

```kusto
requests
| where timestamp > ago(1h)
| summarize executions = count() by bin(timestamp, 1m)
| order by timestamp asc
```

#### Latest executions (table):

```kusto
requests
| where timestamp > ago(1h)
| project timestamp, name, resultCode, duration, success
| order by timestamp desc
```

---

## Phase 2 – Extended POC

### Additions
- VM (`vm-base`) in same RG
- Python heartbeat script running infinite loop (sleep 10s)
- Send alive signal → captured in Application Insights / LAW → visible in Grafana dashboard

### Azure Portal – Steps (Short)

1. **Create VM**
    - Name: `vm-base`
    - RG: `rg-<client>-core`
    - Size: small (e.g., B1s)
    - OS: Ubuntu LTS
    - Networking: allow SSH only
2. **Install Python + Azure Monitor agent**
    - SSH into VM
    - Ensure Python 3 is installed:
      ```bash
      sudo apt update && sudo apt install -y python3-pip
      ```
    - Install Azure Monitor Agent (AMA) → connects VM to LAW
    - Link VM to Log Analytics workspace
    - In Portal: VM → Extensions → Add → AzureMonitorLinuxAgent
    - Select `law-<client>-core`
3. **Python script (heartbeat)**
    - Simple infinite loop: sleep(10) → print/log “alive”
    - Two options to capture signal:
        - **Option A (simpler for POC):** Use Python logging → messages flow via AMA into LAW (Syslog / LinuxSyslog).
        - **Option B (cleaner, cloud-native):** Use Application Insights SDK → send customEvent heartbeat.
    - Place script `/home/<user>/heartbeat.py`
    - Run with:
      ```bash
      nohup python3 heartbeat.py &
      ```
4. **Verify in logs**
    - LAW → Logs → search for Syslog (Option A) or customEvents (Option B).
5. **Grafana dashboard panel**
    - Data source: Azure Monitor → Logs
    - Query heartbeat events:
        - If Syslog:
          ```kusto
          Syslog
          | where TimeGenerated > ago(1h)
          | where ProcessName == "python3"
          | summarize count() by bin(TimeGenerated, 1m)
          ```
        - If Application Insights SDK:
          ```kusto
          customEvents
          | where name == "heartbeat"
          | summarize count() by bin(timestamp, 1m)
          ```

---

## Phase 3: VM for Monitoring

### Sequence (High Level)

1. **Networking & VMs**
    - Create vNet + subnet, NSG allowing intra-subnet traffic.
    - Create `vm_base` and `vm_monitor` in the same subnet.
    - In NSG, allow `vm_monitor` to reach exporters on `vm_base` (ports below).
2. **On vm_base (the app VM)**
    - Node Exporter (exposes basic host metrics; default port 9100).
    - Process Exporter (reports whether your Python process is running; default port 9256).
    - This lets you show a “UP” status in Grafana without touching your app code.
    - (Optional) Promtail (if you also want to show “heartbeat” log lines in Grafana via Loki).
3. **On vm_monitor (the monitoring VM)**
    - Prometheus (scrapes `vm_base`’s exporters; default 9090).
    - Grafana (build dashboards; default 3000).
    - (Optional) Loki (log store) if you installed Promtail on `vm_base`.
    - (Optional) Blackbox Exporter (probes HTTP/TCP endpoints, e.g., ping or curl to `vm_base`; default 9115). Useful if you later expose a simple health port or want ICMP/TCP checks.

---

## Phase 4: VM for Monitoring Adding Azure Function

Two solid, low-cost approaches (no Azure-native telemetry):

### A) Availability Check (No Code Change in Function)

**What you add:**
- On `vm_monitor`: Blackbox Exporter

**How it works:**
- Prometheus scrapes Blackbox Exporter, which probes your Function’s HTTPS URL on a fixed interval.
- You visualize in Grafana:
    - `probe_success` (1/0) → “Last trigger status”
    - `probe_http_status_code` → last HTTP code
    - `probe_duration_seconds` → latency
    - Alert if `probe_success == 0` or “no success in X minutes”.

**When to use:**
- You just need to know the Function is reachable and returning 2xx.
- No code changes in your Function.

### B) Actual Invocation Result Pushed as a Metric (Tiny Code in Function)

**What you add:**
- On `vm_monitor`: Prometheus Pushgateway (optional, but best for “last job result”)
- In the Function: after it runs, POST a metric to Pushgateway (e.g., `function_last_run_status{fn="myfn"} 1` for success, `0` for failure; plus `function_last_run_timestamp`).

**How it works:**
- Function pushes the latest status to Pushgateway.
- Prometheus scrapes Pushgateway.
- Grafana shows:
    - A stat panel for `function_last_run_status` (Success/Fail)
    - “Time since last run” from `function_last_run_timestamp`
    - You can alert on consecutive failures or stale timestamp.

**When to use:**
- You care about the business outcome of the invocation, not just HTTP reachability.

---

### (Optional) Logs in Loki

If you really want a log line per invocation on your existing Loki, you can:
- Expose Loki’s `/loki/api/v1/push` on `vm_monitor` (or keep it private in your subnet/VPN).
- In the Function, send a tiny JSON payload per run to Loki’s push API (or to Promtail’s `loki_push_api` on `vm_monitor`, which then forwards to Loki).
- Grafana can then show “last log line” and frequency panels.
    - (This requires a few lines of HTTP POST in your Function; otherwise there’s no agent on Azure Functions to ship logs out.)

---

## What to Install (and Where), in Order

1. **Network & NSG:** ensure `vm_monitor` can reach the Function URL (public) and that Prometheus can scrape Blackbox / Pushgateway locally.
2. **vm_monitor**
    - Already: Prometheus, Grafana, (optionally Loki)
    - Add Blackbox Exporter (mandatory for “no-code” availability checking)
    - Optional: Pushgateway (only if you want the Function to publish its last-run status)
    - Optional: enable Loki push endpoint if you’ll send logs directly
3. **Prometheus config on vm_monitor**
    - Add a Blackbox job targeting the Function HTTPS URL (with Function key as a header or querystring if required)
    - (Optional) Add a job to scrape Pushgateway
4. **Grafana**
    - Panels for:
        - No-code path: `probe_success`, `probe_http_status_code`, `probe_duration_seconds`
        - Push path: `function_last_run_status`, `function_last_run_timestamp`
    - Alerts as needed.

---

## Security Notes

- Keep Blackbox Exporter and Pushgateway not publicly exposed (only inside subnet or behind your admin IP).
- If your Function requires a key, configure Blackbox probe with the key (header or query param).
- If you later move to Private Endpoints for the Function, ensure `vm_monitor` can resolve/reach it (VNet integration/Premium plan).

---

## TL;DR

- **Cheapest & zero code:** Add Blackbox Exporter on `vm_monitor`; probe the Function URL; graph `probe_success` as “last trigger status.”
- **Richer, business-true status:** Add Pushgateway; Function pushes 1/0 + timestamp; Prometheus scrapes; Grafana shows exact last run result.
- **Logs (optional):** Function posts to Loki push endpoint for per-invocation entries.

 