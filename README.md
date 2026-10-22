# Terraform Azure Landing Zone

A Cloud Adoption Framework (CAF) style **Azure Landing Zone** written in Terraform: management-group governance with Azure Policy guardrails, a hub-and-spoke network with forced egress through Azure Firewall, centralised logging, a private-by-default Key Vault, and a **private AKS cluster** as the first workload landing zone.

Everything is modular — each platform area is a self-contained module with pinned providers — and the `environments/dev` root composes them the way a platform team would run it for real.

> **Status:** configuration is fully `terraform validate`-clean and CI-checked (fmt / validate / tflint / Checkov). It has not been applied to a live tenant — no real subscription IDs are committed anywhere; placeholders (`00000000-0000-0000-0000-000000000000`) mark every spot that needs a real value.

---

## Architecture

```
                        ┌─────────────────────────────────────────────┐
                        │        Management group hierarchy           │
                        │  alz                                        │
                        │  ├── platform (connectivity/identity/mgmt)  │
                        │  ├── landing-zones (corp / online)          │
                        │  ├── sandbox                                │
                        │  └── decommissioned                         │
                        │  Azure Policy: allowed locations · require  │
                        │  tag on RGs · deny public IP on NICs (LZ)   │
                        └─────────────────────────────────────────────┘

  ┌──────────────────────────── HUB (10.0.0.0/16) ────────────────────────────┐
  │ AzureFirewallSubnet   Azure Firewall + policy (egress inspection)         │
  │ AzureBastionSubnet    Azure Bastion (private operator access)             │
  │ GatewaySubnet         reserved for VPN/ExpressRoute gateway               │
  │ SharedServicesSubnet  Key Vault ── private endpoint only, RBAC mode       │
  │ Private DNS zones     privatelink: blob · vault · azurecr (linked to all) │
  └──────────▲───────────────────────────────▲────────────────────────────────┘
          peering                           peering        (no spoke ↔ spoke)
  ┌──────────┴───────────────────┐  ┌────────┴──────────────────────────────┐
  │ WORKLOAD SPOKE 10.1.0.0/16   │  │ APP SPOKE 10.2.0.0/16                 │
  │ snet-aks (/20) ─ PRIVATE AKS │  │ snet-app · snet-data · snet-pe        │
  │ snet-app · snet-pe           │  │ (generic app landing zone)            │
  └──────────────────────────────┘  └───────────────────────────────────────┘
     All spoke egress (0.0.0.0/0 and hub-bound) ──UDR──▶ hub Azure Firewall

  Central Log Analytics workspace (management subscription) receives
  diagnostics from: Azure Firewall · Key Vault · AKS control plane + OMS agent
```

## Modules and CAF mapping

| Module | What it builds | CAF landing-zone area |
| --- | --- | --- |
| [`modules/governance`](modules/governance) | Management-group hierarchy (platform / landing-zones / corp / online / sandbox / decommissioned), subscription placement, Azure Policy assignments using real built-in definitions, management-group-scope RBAC driven by variables | **Enterprise enrolment, identity & governance** — resource hierarchy, policy-as-guardrails, RBAC |
| [`modules/networking`](modules/networking) | Hub VNet (firewall, bastion, gateway, shared-services subnets), two spoke VNets, hub↔spoke peerings (no spoke↔spoke), Azure Firewall + policy (DNS/NTP platform rules, AKS FQDN egress), UDR route tables forcing all spoke egress via the firewall, baseline NSGs, Private DNS zones (blob/vault/ACR) linked to every VNet | **Network topology & connectivity** — hub-spoke, forced tunnelling, private DNS |
| [`modules/monitoring`](modules/monitoring) | Central Log Analytics workspace; every other module streams `azurerm_monitor_diagnostic_setting` (allLogs + AllMetrics) into it | **Management & monitoring** — centralised logging |
| [`modules/shared-services`](modules/shared-services) | Key Vault with public access disabled, private endpoint in the hub, RBAC authorisation (no access policies), purge protection + 90-day soft delete, variable-driven data-plane role assignments | **Security & shared platform services** |
| [`modules/workload-aks`](modules/workload-aks) | Private AKS cluster (no public API endpoint) in the workload spoke: Azure CNI, system + user node pools with autoscaling and zone spread, `userDefinedRouting` egress, Entra ID + Azure RBAC with local accounts disabled, Azure Policy add-on, Container Insights (OMS agent) to the central workspace, plus the Network Contributor grants the cluster identity needs on the VNet and route table | **Platform automation & DevOps / workload landing zone** |
| [`environments/dev`](environments/dev) | Composition root: one azurerm provider alias per subscription (connectivity / management / workload), `azurerm` remote-state backend pattern, example `terraform.tfvars` and `backend.conf` | Environment composition |

## Policy guardrails (governance module)

All three assignments use Microsoft's real built-in policy definitions — no hand-maintained policy JSON:

| Policy (built-in) | Definition ID | Scope | Effect / parameters |
| --- | --- | --- | --- |
| Allowed locations | `e56962a6-4747-49cd-b67b-bf8b01975c4c` | Custom root MG | Deny outside `var.allowed_locations` |
| Require a tag on resource groups | `96670d01-0a4d-4649-9c89-2d3abc0a5025` | Custom root MG | Deny RGs missing `var.required_tag_name` |
| Network interfaces should not have public IPs | `83a86a26-fd1f-447c-b59d-e51f44264114` | Landing Zones MG | Deny (no parameters) |

Scoping is deliberate: the public-IP deny applies to landing zones only, because platform subscriptions legitimately create public IPs (firewall, bastion, gateways). Assignments take an `enforce` switch so a new tenant can onboard in audit-only (`DoNotEnforce`) mode first.

## Design decisions

- **Private AKS, no exceptions.** The API server has no public endpoint; `kubectl` works only from peered networks (or via Bastion-connected jump hosts). Local accounts are disabled in favour of Entra ID + Azure RBAC.
- **Hub-spoke with forced tunnelling.** Spokes have no direct peering and every spoke subnet carries a route table: `0.0.0.0/0` **and** the hub CIDR both next-hop to the firewall's private IP, so internet egress *and* east-west traffic are inspected in one place. The AKS cluster uses `outbound_type = userDefinedRouting` to match — which is why the module also grants its identity Network Contributor on the VNet and route table.
- **Policy as guardrails, not gates in pipelines.** Region, tagging and network-exposure rules are enforced by Azure Policy at the management-group scope, so they hold no matter which tool provisions a workload.
- **Private PaaS by default.** Key Vault is reachable only through a private endpoint, with RBAC-mode authorisation and purge protection. Private DNS zones for Storage, Key Vault and ACR are created centrally and linked to all three VNets, so private endpoints resolve consistently everywhere.
- **One logging sink.** A single Log Analytics workspace in the management subscription receives firewall, Key Vault and AKS diagnostics — the pattern each module implements with `azurerm_monitor_diagnostic_setting`.
- **No real IDs in git.** Subscription IDs, Entra group object IDs and the state-storage account are all placeholders/examples; real values belong in your own (git-ignored) `terraform.tfvars` / `backend.conf`.

## Adapting this to a real subscription

Prerequisites: Terraform ≥ 1.9, Azure CLI logged in as an identity that can create management groups and assignments (typically *Management Group Contributor* + *Resource Policy Contributor* at the tenant root, and *Owner*/*User Access Administrator* for the RBAC assignments), and three subscriptions (connectivity, management, workload).

1. **Bootstrap state storage** (once, outside this repo): a resource group + storage account + `tfstate` container.
2. **Fill in your values:**
   ```bash
   cd environments/dev
   cp backend.conf.example backend.conf          # your state storage details
   cp terraform.tfvars.example terraform.tfvars  # your subscription IDs,
                                                 # Entra group object IDs,
                                                 # a globally-unique Key Vault name
   ```
3. **Deploy:**
   ```bash
   terraform init -backend-config=backend.conf
   terraform plan
   terraform apply
   ```
   Tip: on a brand-new tenant, apply `module.governance` first (`terraform apply -target=module.governance`) so subscriptions are filed and guardrails exist before any workload lands.
4. **Use it:** get AKS credentials with `az aks get-credentials` from a machine inside the peered network (the API server is private), and grant the kubelet identity (root output `aks_kubelet_identity_object_id`) `AcrPull` when you add a registry.

## Repository layout

```
modules/
  governance/       management groups · policy assignments · MG-scope RBAC
  networking/       hub & spokes · firewall · peerings · routes · private DNS
  monitoring/       central Log Analytics workspace
  shared-services/  private Key Vault (+ private endpoint, RBAC, diagnostics)
  workload-aks/     private AKS cluster (system + user pools, UDR egress)
environments/
  dev/              composition root, provider aliases, backend pattern,
                    terraform.tfvars.example, backend.conf.example
.github/workflows/  CI: fmt · validate (per module) · tflint · Checkov
```

## Local checks

```bash
terraform fmt -check -recursive
for d in modules/* environments/dev; do
  (cd "$d" && terraform init -backend=false && terraform validate)
done
```

## What this demonstrates

- CAF enterprise-scale thinking in code: hierarchy, guardrails and subscription placement before any workload exists
- Production hub-spoke networking: firewall-centric egress, UDR design, peering flags (`allow_forwarded_traffic`, gateway transit) used correctly, Private Link DNS done centrally
- A genuinely hardened AKS baseline: private control plane, Azure CNI capacity planning (/20 node subnet), identity/RBAC wiring that UDR clusters actually require, policy add-on, centralised control-plane logging
- Terraform craft: small composable modules with pinned providers, provider aliases per subscription, variable-driven RBAC/policy, placeholder discipline (zero real IDs in the repo), and CI that validates every module independently

## Limitations & next steps

- Not applied to a live tenant from this repo (no credentials) — `plan`/`apply` behaviour is untested here; validate and CI are green.
- `GatewaySubnet` is reserved but no VPN/ExpressRoute gateway is deployed; enabling one means flipping the gateway-transit flags in `peering.tf`.
- Natural extensions: Azure Container Registry with private endpoint + `AcrPull` for the kubelet identity (the `acr` Private DNS zone is already linked), Azure Policy *initiatives* (e.g. the AKS baseline) alongside the individual assignments, and a `prod` environment root reusing the same modules with larger address spaces and node pools.
