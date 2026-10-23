# Démo — Metabase sur Clever Kubernetes

Copier-coller pour le tournage. Bloc par bloc, dans l'ordre.
`ORG` et `CLUSTER` sont posés une fois, tout le reste s'enchaîne.

> ⚠️ **Écran** : `clear` avant de commencer. Ne JAMAIS afficher `clever addon env`,
> le kubeconfig (`cat`), ni `kubectl get secret -o yaml` → ils contiennent des secrets.
> Les commandes ci-dessous sont toutes safe à l'écran (les secrets transitent sans s'imprimer).

```bash
clear
export ORG=orga_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   # ton ID d'organisation (clever profile / console)
export CLUSTER=metabase-demo
```

## 1. Créer le cluster (XS:3, attend l'ACTIVE)

```bash
clever k8s create $CLUSTER --nodegroup XS:3 --org $ORG --watch -y
```

## 2. Add-on PostgreSQL (base applicative de Metabase)

```bash
clever addon create postgresql-addon metabase-demo-db --plan xxs_sml --region par --org $ORG -y
```

## 3. Kubeconfig dans un fichier dédié (ne PAS écraser ~/.kube/config)

```bash
clever k8s get-kubeconfig $CLUSTER --org $ORG > ~/.kube/metabase-demo.yaml
export KUBECONFIG=~/.kube/metabase-demo.yaml
kubectl get nodes          # les 3 nœuds doivent passer Ready
```

## 4. Déployer Metabase (Namespace + Deployment + Service LoadBalancer)

```bash
kubectl apply -f metabase.yaml
```

## 5. Secret depuis les credentials de l'add-on (safe : rien ne s'affiche)

```bash
./create-secret.sh metabase-demo-db
kubectl -n metabase rollout restart deployment/metabase   # le pod a démarré avant le secret
```

## 6. Attendre, récupérer l'IP publique, vérifier la santé

```bash
kubectl -n metabase rollout status deployment/metabase --timeout=300s
kubectl -n metabase get svc metabase                      # colonne EXTERNAL-IP
IP=$(kubectl -n metabase get svc metabase -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://$IP/api/health                             # {"status":"ok"}
echo "→ Metabase : http://$IP"
```

## Teardown (fin de tournage)

```bash
clever k8s delete $CLUSTER --org $ORG -y
clever addon delete metabase-demo-db --org $ORG -y
# le quota LoadBalancer/vCPU se libère en ~2-3 min avant de recréer
```
