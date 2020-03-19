# Documentation

Ce document est à destintation des développeurs qui utilisent l'environnement.

## ETQDev je veux déployer le frontend et le backend

Pour déployer, je dois push sur la bonne branche.

- Je push sur la branche `staging` pour déployer sur l'environnement
  d'intégration.
- Je push sur la branche `master` pour déployer sur l'environnement de
  production.

## ETQDev je veux voir l'avancement d'un déploiement

Dans la console AWS, grâce aux pages [CodePipeline](https://console.aws.amazon.com/codesuite/codepipeline/pipelines) et [CodeBuild](https://console.aws.amazon.com/codesuite/codebuild/projects), je peux voir l'avancement de tous les pipelines.


## ETQDev je veux me connecter au cluster Kubernetes

J'installe `kubectl` :

```bash
brew install kubectl            # Sur Mac
snap install kubectl --classic  # Sur Ubuntu
```

J'installe [`kubectx`](https://github.com/ahmetb/kubectx) :

```bash
brew install kubectx fzf      # Sur Mac
sudo apt install kubectx fzf  # Sur Ubuntu
```

J'utilise la commande suivante pour ajouter le contexte Kubernetes du cluster EKS:

```
aws eks --region <REGION> update-kubeconfig --name <CLUSTER_NAME>
```

Dans l'exemple ci-dessus, je dois remplacer `<REGION>` par la nom de la région du cluster EKS et je dois remplacer `<CLUSTER_NAME>` par le nom du cluster EKS.

Je liste les clusters disponibles :

```bash
kubectx
```

Je configure kubectl pour utiliser le cluster que je veux :

```bash
kubectx mon-cluster-de-prod
```

## ETQDev je veux savoir quels pods tournent

```bash
# Je liste tous les pods
kubectl get pods

# Je liste uniquement les pods qui tournent
kubectl get pods --field-selector status.phase=Running
```

Davantage d'information sur les _Field Selectors_ [ici](https://kubernetes.io/docs/concepts/overview/working-with-objects/field-selectors/).

## ETQDev je veux lire les logs d'un pod

```bash
# Si mon pod a un seul container
kubectl logs mon-pod

# Si mon pod a plusieurs containers
kubectl logs mon-pod mon-container
```

## ETQDev je veux un shell dans un pod

```bash
kubectl exec -it mon-pod /bin/sh
```

## ETQDev je veux ajouter une variable d'environnement

Je dois modifier le champ `configmap` des fichiers `values.staging.yaml` et
`values.prod.yaml` de mon chart Helm. Par exemple, pour ajouter une variable
`API_KEY` et une variable `DB_USER` :

```yaml
configmap:
  API_KEY: 0123456789abcdef
  DB_USER: username
```

## ETQDev je veux ajouter un secret

Dans la console AWS, je navigue jusqu'à la page [AWS Secret Manager](https://console.aws.amazon.com/secretsmanager/) puis je vais dans la section "Secrets". Ici, je peux ajouter un
secret à AWS Secret Manager. Je prends note du nom que je donne au secret.

Afin d'utiliser le secret depuis un pod, je dois modifier le fichier
`templates/deployment.yaml` de mon chart Helm.

Je trouve la ligne où est définie la variable d'environnement `ASSETS_BUCKET` et j'ajoute, en dessous, une variable d'environnement comme ceci :

```yaml
- name: ASSETS_BUCKET
  value: "{{ .Values.aws.backend.bucket }}"
- name: <SECRET_KEY>
  value: <ACCESS_KEY>
```

Dans l'exemple ci-dessus, je dois remplacer `<SECRET_KEY>` par le nom de la clé du secret et `<ACCESS_KEY>` par le nom de la clé d'accès au secret.

## ETQDev je veux me connecter à ma DB

Mon backend doit se référer aux variables d'environnement suivantes :

- `DB_HOST`, l'addresse IP de la base de données
- `DB_PORT`, le port où écoute la base de données
- `BD_USER`, l'utilisateur à utiliser pour s'authentifier
- `DB_PASSWORD`, le mot-de-passe à utiliser pour s'authentifier
- `DB_NAME`, le nom de la base de données

Je peux déployer un client PostgreSQL pour accéder à la DB directement :

```bash
BACKEND_POD="mon-pod-de-backend"

DB_VARS="$(kubectl exec "$BACKEND_POD" printenv | grep DB_)"
kubectl run access-to-db --rm -it --image postgres $(echo $DB_VARS | sed -e 's/^/--env=/') -- bash
```

Depuis le client PostgreSQL, je me connecte comme ceci :

```bash
psql "postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
```

## ETQDev je veux que mon backend accède au buket d'assets

Mon backend doit se référer aux variables d'environnement suivantes :

- `ASSETS_BUCKET`, le nom du bucket où le backend stocke les assets
- `AWS_SHARED_CREDENTIALS_FILE`, l'emplacement d'identifiants donnant accès au bucket


Depuis un shell dans mon pod de backend, j'installe la bibliothèque cliente :

```bash
pip install boto3
```

Je peux ensuite me connecter au bucket avec Python :

```python
import boto3

# Création d'une resource s3 qui me permet de communiquer avec le service s3
s3 = boto3.resource('s3')

for bucket in s3.buckets.all():
    print(bucket.name)
```

Pour davantage d'information, je me réfère à [la documentation AWS](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/quickstart.html).
