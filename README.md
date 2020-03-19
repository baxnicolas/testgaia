# AWS Resources Setup

In this folder, you've got two main parts:

 - `aws-infrastructure`, will contain
    - users
    - ecr
 - `aws-environments`, will contain
    - staging
       - eks
       - rds
       - etc
       - s3
       - ...
    - production
       - eks
       - rds
       - etc
       - s3
       - ...

A full description of the services is available [here](./README_aws_services.md).

## PREPARE THE DEPLOYMENT 

### 0 - Be sure you have the 12 version of terraform

```bash
terraform version
```

The version **needs to be 0.12.19**.

### 1 - Create the Role that will be used by Terraform

You need to be connected with the root AWS account.
Create a new Role : 
- When selecting the type of trusted entity, choose "Another AWS account"
- Put the AWS organisation ID
- Attach it the AdministratorAccess policy
- Name it DevOps 

### 2 - Set up local environment

In order to access to the accounts you need to create an AWS profile.
Find the root access keys in the IAM part of the AWS console and then edit the `~/.aws/config` and `~/.aws/credentials` files:

```bash
# ~/.aws/credentials
[<PROFILE_NAME>]
aws_access_key_id = <ACCESS_KEY_ID>
aws_secret_access_key = <SECRET_ACCESS_KEY>

# ~/.aws/config
[profile <PROFILE_NAME>]
region = <DESIRED_REGION>
```

The profile name could be built as followed : gaia_<client_name>_root (eg: gaia_armany_root)

```bash
export AWS_PROFILE=<PROFILE_NAME>
```

### 3 - Create Terraform Bucket

Create the terraform bucket which will contain the state by running: 

```bash
aws s3 mb s3://<COMPANY>-terraform-states
```

### 4 - Deploy the resources

#### Init Terraform

Add these parameters in your env:
```bash
export COMPANY="<COMPANY>"
export REGION="<REGION>"
export DNS_ROOT_DOMAIN="<DNS_ROOT_DOMAIN>"
export GITHUB_OWNER_ACCOUNT="<GITHUB_OWNER_ACCOUNT>"
export GITHUB_REPOSITORY="<GITHUB_REPOSITORY>"
export AWS_ACCOUNT_ID="<AWS_ACCOUNT_ID>"
```

Then, **be sure to be at the root of the client repository** and customize your project-related vars:

```bash
find . -type f | xargs sed -i'' "s:<COMPANY>:${COMPANY}:g"
find . -type f | xargs sed -i "s:<REGION>:${REGION}:g"
find . -type f | xargs sed -i "s:<DNS_ROOT_DOMAIN>:${DNS_ROOT_DOMAIN}:g"
find . -type f | xargs sed -i "s:<GITHUB_OWNER_ACCOUNT>:${GITHUB_OWNER_ACCOUNT}:g"
find . -type f | xargs sed -i "s:<GITHUB_REPOSITORY>:${GITHUB_REPOSITORY}:g"
find . -type f | xargs sed -i "s:<AWS_ACCOUNT_ID>:${AWS_ACCOUNT_ID}:g"
```

NB: these commands are not working on Mac, use the famous CMD+R to do the job :)

Additionaly, you can edit any other variables according to your needs:

```bash
vi aws-infrastructure/variables.tf
vi aws-environments/variables.tf
```
Be careful to put the right devops users you want (line 13 of the aws-infrastructure variables file)

And init Terraform resources :

```bash
cd terraform/aws/aws-infrastructure
terraform init

cd terraform/aws/aws-environments
terraform init
terraform workspace new app-staging
terraform workspace new app-prod
terraform workspace select app-staging
```

#### Deploy infrastructure components

```bash
cd terraform/aws/aws-infrastructure
terraform plan
terraform apply
```

Will perform:

- `iam_users-groups.tf` : using iam policy files in `files/iam_group_policy_*`
- `ecr.tf`

After that, modify the Access Key Id and Secret Access Key you've set earlier, by putting those dedicated to your created user.

#### Deploy environments components

We will deploy staging environment:

```bash
export WORKSPACE="app-staging"
```

First, make sure you've created the Github token for the webhook:

- Go to the GitHub web UI
- Go to your service account settings page
- Create a Personal access token inside the Developers setting with the rights repo and admin:repo_hook
- Store this token in AWS Secret Manager under:
  - Secret name github-token
  - Secret key GITHUB_TOKEN

#### Specific first step

First, for `AWS` we need to do something before being abled to apply our terraform manifests,
this is because of a missing feature in `EKS` -> **the choice of CNI** (Container Network Interface)
since we want to install `weave-net` in the cluster we'll need to **remove the embedded AWS CNI**.

In order to do so:

- First, modify the variables in `aws-environments/variables.tf`:
   - ***nodes_instance_desired*** to `0`
   - ***nodes_instance_min*** to `0`.
- And check if the following lines are commented in `aws-environments/kubernetes_nodes.tf`, as follow:
```hcl
resource "aws_autoscaling_group" "env_cluster_nodes" {
...
...
  # lifecycle {
  #   ignore_changes = [desired_capacity]
  # }
```

To keep it simple we don't want to deploy any worker nodes before removing the AWS-CNI.

Now simply deploy using `Terraform` command:

```bash
cd aws/aws-environments
terraform workspace select ${WORKSPACE}
terraform apply
```

**Note that the first time it will fail.**

Once you've applied and it's failing at the helm part, you need to delete the aws-node daemonset manually:

```bash
kubectl delete ds -n kube-system aws-node
```

After that you can modify the variables again in `aws-environments/variables.tf`:

- ***nodes_instance_desired*** to `3`
- ***nodes_instance_min*** to `3`.

Then try again Kubernetes deployment:

```bash
terraform plan
terraform apply
```

Last but extremely important step, we'll need to uncomment something in the `aws-environments/kubernetes_nodes.tf` file:

```hcl
resource "aws_autoscaling_group" "env_cluster_nodes" {
...
...
  # lifecycle {
  #   ignore_changes = [desired_capacity]
  # }
```

Then `terraform apply` again.

#### Kubernetes credentials

If the deployment fails for Kubernetes credentials problems,
try to get them using AWS CLI:

```bash
aws eks --region ${REGION} update-kubeconfig --name env-${WORKSPACE}-cluster
```

And then try again to `terraform apply`


### TROUBLESHOOTING 

#### DNS problems

If your DNS main zone, let's say <COMPANY>.co for example,
is managed by AWS,
then this should not happen.

Yet the deployment could fail due to the DNS config or certificate
being to long to go through.

In this case just wait a little.

If however DNS main zone is managed by another DNS provider,
then you need to manually configure DNS delegation.

For `Gandi` delegation, see `gandi.md` readme.

When you delegation is OK, try again the `terraform apply`  command.

#### Indicative order of deployment:

- network
    - network_vpc.tf
    - dns
       - route53.tf
          - Désactiver la partie lien avec un DNS compagnie pour les tests
    - security
       - kubernetes_security.tf
       - acm.tf
          - Prend beaucoup de temps en raison de la validation du certificat (c.f. AWS Certificate Manager)
            - Ne fonctionne qu'avec un nom de domaine qu'on contrôle
            - désactiver la partie en trop pour les tests

    *** CHECKPOINT ***

    - kube
       - kubernetes.tf
       - kubernetes_nodes.tf
       - kubernetes_roles.tf

    *** CHECKPOINT ***

    - kube-plugins
       - CNI genie -> enable using more than one CNI, chosen at pod deployment time
       - CNI weave-net


### Deploy AWS CI

In order to deploy `aws-ci` proceed in 2 steps.

#### Update the environment

Go to `aws-environment` and update the variable `kubernetes_additional_users` in `variables.tf` like this:

```bash
variable "kubernetes_additional_users" {
  type    = map
  default = {
    "app-staging" = { "<COMPANY>-env-app-staging-codebuild-role" = "role" }
    "app-prod" =    { "<COMPANY>-env-app-prod-codebuild-role"    = "role" }
  }
}
```

Then perform a `terraform update` for your current environment (either app-staging or app-prod).

#### Deploy CodePipeline and CodeBuild

Go to `aws/aws-ci` dir.

In `variables.tf` define:

- `bucket_front_id` with the front bucket name (deployed with aws-environment)

Then perform:

```bash
terraform init
terraform workspace new app-staging
terraform workspace new app-prod

terraform workspace select app-staging

terrform apply
```

# Use environment

## Test cluster connection

Chose your workspace:

```bash
export WORKSPACE="app-staging"
```

And then get your credentials:

```bash
aws sts get-caller-identity
aws eks --region ${REGION} update-kubeconfig --name env-${ENV_WORKSPACE}-cluster
```

Then
```bash
kubectl get po
```

## Test database access

Connect to `tiller` pod:

```bash
kubectl -n kube-system exec -it tiller-deploy-5b6554dd68-lqb55 /bin/sh
```

Then try to connect using `nc`

```bash
nc -vv database.default.svc.cluster.local 5432
```

The command should answer `open`


## Test buckets

### Test front bucket

Create a file, named `index.html`, with the following content:

```html
<html>
<header><title>This is title</title></header>
<body>
Hello world
</body>
</html>
```

Then upload it to the front bucket:

```bash
aws s3 cp index.html s3://${COMPANY}-env-${ENV_WORKSPACE}-front/
```

Then request it:

```bash
curl http://${COMPANY}-env-${ENV_WORKSPACE}-front.s3-website-eu-west-1.amazonaws.com/
```
