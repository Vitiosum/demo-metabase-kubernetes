

« Je crée mon cluster avec un nodegroup de 3 nœuds XS. Le --watch attend qu'il soit actif.
Ce que vous ne voyez pas — et c'est le point clé — c'est que le control-plane est entièrement managé par Clever Cloud : les mises à jour, la haute dispo, le durcissement sécurité, c'est nous. Vous, vous ne gérez que vos workloads. »

« Metabase a besoin d'une base pour ses métadonnées. Plutôt que de faire tourner un PostgreSQL fragile dans le cluster, je provisionne un add-on managé Clever Cloud. Backups, monitoring, patchs : gérés. C'est la bonne pratique — on ne met pas sa donnée critique dans un pod éphémère. »

« Je récupère mon kubeconfig. Et ça, c'est important : c'est du Kubernetes vanilla, 100 % standard. Vos outils habituels — kubectl, Helm, votre CI — fonctionnent tels quels. Pas de CLI propriétaire pour piloter vos workloads, pas de lock-in. »

« J'applique un manifest Kubernetes tout ce qu'il y a de plus standard. Notez le Service de type LoadBalancer : sur beaucoup de plateformes il faut configurer un contrôleur d'ingress, réserver une IP… Ici, regardez ce qui va se passer. »

« Je connecte Metabase à sa base via un Secret Kubernetes, alimenté directement par les credentials de l'add-on. Les identifiants ne sont jamais en dur dans mon manifest — bonne hygiène de sécurité. »

« Et voilà le point que je vous ai teasé : le Service LoadBalancer a automatiquement une IP publique. Aucune config réseau, aucun ingress à écrire. Je vérifie le health check… status: ok. Metabase est en ligne, joignable, prêt à l'emploi. »

« Récapitulons : un cluster Kubernetes managé, une base PostgreSQL managée, une application déployée et exposée publiquement — le tout en quelques commandes, quelques minutes, sans gérer un seul control-plane ni une seule règle réseau. Du Kubernetes standard, sans la charge opérationnelle. C'est exactement la promesse de Clever Cloud : vous vous concentrez sur vos applications, on s'occupe du reste. »
