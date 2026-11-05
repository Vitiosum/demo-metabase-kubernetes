# Metabase in five commands — Kubernetes and PostgreSQL on Clever Cloud

> [Metabase](https://www.metabase.com/) deployed on **Clever Kubernetes**, Clever Cloud's managed Kubernetes, with its application database on a **managed PostgreSQL add-on** outside the cluster, and exposed publicly by a `LoadBalancer` Service that gets its public IP on its own. The control plane is run by Clever Cloud; you only handle your workloads, with plain `kubectl` and a standard manifest. The database credentials go from the add-on to a Kubernetes `Secret` without ever being printed or written in the manifest. Companion repository of a YouTube video.

![Architecture: the Internet reaches a LoadBalancer Service on port 80, which forwards to the Metabase Deployment on port 3000 in a Clever Kubernetes cluster with a managed control plane; the pod reads the metabase-db Secret, written by create-secret.sh from the PostgreSQL add-on's credentials, and talks to the add-on outside the cluster](docs/architecture.png)

**Run it yourself.** The hosted demo was taken down after the presales review (November 2026). The steps in [Deploy on Clever Cloud](#deploy-on-clever-cloud) recreate it from scratch in about 15 minutes, including Metabase's first start (2 to 3 minutes).

**Get certified.** This demo runs on Clever Cloud. To deploy your own apps the same way, get certified at the [Clever Cloud Academy](https://academy.clever.cloud/).

## What Clever Kubernetes does here

| Where | Clever Cloud feature | What you see |
|---|---|---|
| Cluster | `clever k8s create --nodegroup XS:3 --watch`: managed control plane, three XS nodes | The command returns once the cluster is active; upgrades, high availability and hardening of the control plane are not yours |
| Access | `clever k8s get-kubeconfig` | A standard kubeconfig: `kubectl`, Helm and your CI work as they are, no proprietary CLI for the workloads |
| Exposure | `Service` of type `LoadBalancer`, once the admin account exists | A public IP assigned automatically, no ingress controller to install, no IP to reserve (L4, HTTP) |
| Data | PostgreSQL add-on, plan `xxs_sml`, zone `par` | Metabase's application database outside the cluster, with backups, monitoring and patches handled by the platform, not in an ephemeral pod |
| Credentials | `clever addon env --format shell`, read by `create-secret.sh` | The `metabase-db` Secret, created without displaying anything |

```
            Internet
               │  http://<EXTERNAL-IP>
               ▼
   ┌───────────────────────────┐
   │ Service LoadBalancer :80  │   automatic public IP (L4, HTTP)
   └─────────────┬─────────────┘
                 ▼ :3000
   ┌───────────────────────────┐        ┌──────────────────────────┐
   │ Deployment metabase       │ ─────▶ │ Managed PostgreSQL add-on│
   │ metabase/metabase:v0.50.30│ Secret │ (plan xxs_sml, zone par) │
   └───────────────────────────┘        └──────────────────────────┘
     Clever Kubernetes cluster (nodegroup XS:3, managed control plane)
```

## Deploy on Clever Cloud

You need [clever-tools](https://www.clever.cloud/developers/doc/cli/) (`clever login` done) with the Kubernetes feature enabled (`clever features enable k8s`), `kubectl`, and an organisation with access to Kubernetes (`orga_…`, shown in the Console). The default quota does not allow an `M:2` node group, hence `XS:3`. Run the commands from the repo root.

```bash
export ORG=<org_id>
export CLUSTER=metabase-demo

# 1. The managed cluster (--watch waits until it is active)
clever k8s create $CLUSTER --nodegroup XS:3 --org $ORG --watch -y

# 2. The PostgreSQL add-on, Metabase's application database
clever addon create postgresql-addon metabase-demo-db --plan xxs_sml --option encryption=true --region par --org $ORG -y

# 3. The kubeconfig, in a dedicated file (~/.kube/config is left alone)
clever k8s get-kubeconfig $CLUSTER --org $ORG > ~/.kube/metabase-demo.yaml
export KUBECONFIG=~/.kube/metabase-demo.yaml
kubectl get nodes                      # the three nodes turn Ready

# 4. Deploy: Namespace, Deployment, internal Service (ClusterIP)
kubectl apply -f metabase.yaml

# 5. The database Secret, then a restart (the pod started before the Secret existed)
./create-secret.sh metabase-demo-db
kubectl -n metabase rollout restart deployment/metabase
kubectl -n metabase rollout status deployment/metabase --timeout=300s

# 6. The admin account, before anyone else can reach Metabase
kubectl -n metabase port-forward svc/metabase 3000:80
# open http://localhost:3000, create the admin account, then Ctrl-C

# 7. Expose it: the Service becomes a LoadBalancer and gets a public IP
kubectl -n metabase patch svc metabase -p '{"spec":{"type":"LoadBalancer"}}'
until IP=$(kubectl -n metabase get svc metabase -o jsonpath='{.status.loadBalancer.ingress[0].ip}') && [ -n "$IP" ]; do sleep 5; done
curl -s http://$IP/api/health          # {"status":"ok"}
echo "Metabase: http://$IP"
```

Metabase's first start (migrations of its database) takes 2 to 3 minutes. It then opens on its setup wizard, and whoever reaches it first creates the admin account: that is why the Service starts internal and the account is created through `kubectl port-forward` before step 7 gives it a public IP. `create-secret.sh` finds the add-on by name in the `$ORG` organisation, so there is no ID to copy and paste.

**Clean up**

```bash
clever k8s delete $CLUSTER --org $ORG -y
clever addon delete metabase-demo-db --org $ORG -y
rm ~/.kube/metabase-demo.yaml
```

After a deletion, wait 2 to 3 minutes for the vCPU and LoadBalancer quota to be released before creating again.

## Variables

| Variable | Set by | Role |
|---|---|---|
| `MB_DB_TYPE` | `metabase.yaml` | `postgres` |
| `MB_DB_HOST`, `MB_DB_PORT`, `MB_DB_DBNAME`, `MB_DB_USER`, `MB_DB_PASS` | `create-secret.sh`, from the add-on's `POSTGRESQL_ADDON_HOST`, `_PORT`, `_DB`, `_USER`, `_PASSWORD` | Secret `metabase-db`, read by the pod with `envFrom` |
| `ORG`, `CLUSTER` | you, in the shell | Organisation and cluster name for the commands above |
| `KUBECONFIG` | you, in the shell | Points `kubectl` at `~/.kube/metabase-demo.yaml` |

## Routes

`http://<EXTERNAL-IP>/` Metabase · `/api/health` `{"status":"ok"}`, also used by the readiness probe (from 60 s, every 10 s, up to 30 failures) and the liveness probe (from 180 s, every 30 s).

## Code tour

| File | Role |
|---|---|
| [`metabase.yaml`](metabase.yaml) | Namespace, Deployment (pinned image `metabase/metabase:v0.50.30`, 1 replica, requests 500m CPU and 1 Gi, limit 2 Gi, probes on `/api/health`) and a Service (80 → 3000), internal until step 7 makes it a LoadBalancer |
| [`create-secret.sh`](create-secret.sh) | Creates the `metabase-db` Secret from the add-on's credentials (prints nothing) |
| [`DEMO.md`](DEMO.md) | The commands, block by block, in the order of the recording (French) |
| [`SCRIPT-VIDEO.md`](SCRIPT-VIDEO.md) | The voice-over of the video (French) |

## Watch-outs

- **CLI command**: `clever k8s …`, not `clever kubernetes …`.
- **PostgreSQL plan**: avoid `dev` (5 connections at most), too tight for Metabase's connection pool.
- **HTTP only**: the LoadBalancer works at L4. For a domain over HTTPS, add an ingress and cert-manager.
- **Secrets on screen**: never display `clever addon env`, the kubeconfig or `kubectl get secret -o yaml` during a recording.

## Run on another cluster

The manifest is plain Kubernetes. On another cluster, create the `metabase-db` Secret in the `metabase` namespace with your own PostgreSQL's five `MB_DB_*` values instead of running `create-secret.sh`; the Service needs a cluster that provides `LoadBalancer` IPs.
