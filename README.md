# Metabase sur Clever Kubernetes

Déployer [Metabase](https://www.metabase.com/) sur le **Kubernetes managé de Clever Cloud**, avec sa base de métadonnées sur un **add-on PostgreSQL managé**, et l'exposer publiquement via un `Service` de type `LoadBalancer`, en 5 commandes.

Dépôt compagnon de la vidéo YouTube.

## Architecture

```
            Internet
               │  http://<EXTERNAL-IP>
               ▼
   ┌───────────────────────────┐
   │ Service LoadBalancer :80  │   IP publique auto (L4, HTTP)
   └─────────────┬─────────────┘
                 ▼ :3000
   ┌───────────────────────────┐        ┌──────────────────────────┐
   │ Deployment metabase       │ ─────▶ │ Add-on PostgreSQL managé │
   │ metabase/metabase:v0.50.30│ Secret │ (plan xxs_sml, région par)│
   └───────────────────────────┘        └──────────────────────────┘
     Cluster Clever Kubernetes (nodegroup XS:3, control-plane managé)
```

- **Control-plane** : géré par Clever Cloud. Vous ne pilotez que vos workloads.
- **Base applicative** : hors du cluster, sur un add-on managé (backups, monitoring, patchs). Pas de PostgreSQL dans un pod éphémère.
- **Credentials** : injectés via un `Secret` Kubernetes généré depuis `clever addon env`. Ils ne sont jamais écrits dans le manifest.
- **Kubernetes standard** : `kubectl`, Helm et votre CI fonctionnent sans adaptation.

## Contenu

| Fichier | Rôle |
|---|---|
| [`metabase.yaml`](metabase.yaml) | Namespace, Deployment (image épinglée, probes `/api/health`) et Service LoadBalancer |
| [`create-secret.sh`](create-secret.sh) | Crée le Secret `metabase-db` à partir des credentials de l'add-on (n'affiche rien) |
| [`DEMO.md`](DEMO.md) | Les commandes, bloc par bloc, dans l'ordre du tournage |
| [`SCRIPT-VIDEO.md`](SCRIPT-VIDEO.md) | Le texte dit à l'oral pendant la vidéo |

## Prérequis

- [clever-tools](https://github.com/CleverCloud/clever-tools) installé et connecté (`clever login`), feature Kubernetes activée : `clever features enable k8s`
- `kubectl`
- Une organisation Clever Cloud avec accès à Kubernetes. Le quota par défaut ne permet pas un nodegroup `M:2`, d'où `XS:3`.

## Démarrage rapide

```bash
export ORG=orga_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export CLUSTER=metabase-demo

# 1. Cluster managé
clever k8s create $CLUSTER --nodegroup XS:3 --org $ORG --watch -y

# 2. Base PostgreSQL managée
clever addon create postgresql-addon metabase-demo-db --plan xxs_sml --region par --org $ORG -y

# 3. Kubeconfig dans un fichier dédié (on n'écrase pas ~/.kube/config)
clever k8s get-kubeconfig $CLUSTER --org $ORG > ~/.kube/metabase-demo.yaml
export KUBECONFIG=~/.kube/metabase-demo.yaml

# 4. Déploiement
kubectl apply -f metabase.yaml

# 5. Secret de connexion à la base, puis redémarrage (le pod a démarré avant le Secret)
./create-secret.sh metabase-demo-db
kubectl -n metabase rollout restart deployment/metabase
kubectl -n metabase rollout status deployment/metabase --timeout=300s

# IP publique et health check
IP=$(kubectl -n metabase get svc metabase -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://$IP/api/health   # {"status":"ok"}
echo "Metabase : http://$IP"
```

Le premier démarrage de Metabase (migrations de la base) prend 2 à 3 minutes.

## Nettoyage

```bash
clever k8s delete $CLUSTER --org $ORG -y
clever addon delete metabase-demo-db --org $ORG -y
rm ~/.kube/metabase-demo.yaml
```

Après une suppression, attendre 2 à 3 minutes que le quota vCPU/LoadBalancer se libère avant de recréer.

## Points d'attention

- **Commande CLI** : `clever k8s …`, et non `clever kubernetes …`.
- **Plan PostgreSQL** : éviter `dev` (5 connexions max), trop juste pour le pool de connexions de Metabase.
- **HTTP uniquement** : le LoadBalancer travaille en L4. Pour un domaine en HTTPS, ajouter un ingress et cert-manager.
- **Secrets à l'écran** : ne jamais afficher `clever addon env`, le kubeconfig ni `kubectl get secret -o yaml` pendant un enregistrement.
