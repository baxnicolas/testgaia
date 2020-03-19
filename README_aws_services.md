### AWS Services

Here a brief explanation of the role of every AWS service used and the resources deployed.

#### IAM (Identity and Access Management)

Resources:
- Users: one user for each member of the developer/operations team.
- Groups: each user is associated with one or more group (ex: Developers, DevOps, etc.).
- Policies: policies are mainly associated to roles. Policies are also created for each service (and attached to its role) to allow its access to other AWS services
- Roles: Most action on the AWS cluster are done via a role for better permission management.

#### VPC (Virtual Private Cloud)

The Nerwork resources are created in the way described in the following figure:
![AWS network](images/gaia_aws_network.png)

Resources:
- VPC: one vpc is created per environment.
- subnets: two subnets are created per environment (one Private and one Public) and per availability zone. So if two availability zone are used, four subnets would be created.
- NAT Gateway
- Internet Gateway
- Routing Tables

#### EKS (Kubernetes managed cluster)

EKS makes it possible to deploy quickly a kubernetes cluster without having to deal with the kubernetes internal resources (API server, etcd, kubelet, etc.) deployment or their replication.

Resources:
- Cluster: One cluster is created per environment.

#### Route53 (DNS)

Resources:
- Zone: One zone is created per environment
- Records:
	- Backend (A) points to the api deployed in the kubernetes cluster
	- Frontend (A) points to the S3 bucket used to store the static files of the website
	- Grafana (A) points to grafana deployed in the kubernetes cluster


#### Secret Manager

Gaïa uses secret manager to store some passwords created during resource provisioning (Database password, Grafana password, Github token, etc.)
It also deploys it the kubernetes cluster a poller that will sync any password created in Secret Manager with the kubernetes password so it is easily available to any application present in the cluster.

Resources:
- Database Password
- Github Token
- Grafana Password

#### CloudWatch (Monitoring)

Gaïa sets up CloudWatch to collect app of the pods deployed in the kubernetes cluster.

Resources:
- Logs group: One log group is deployed for each kubernetes cluster in the environment.

#### ECR (Docker image repository)

ECR is the Docker image repository.
It stores any Docker image built during the CI/CD process by CodeBuild. 
Those images will then be deployed into the kubernetes cluster by Helm (which is also used via CodeBuild)

Resources:
- Repository: One repository is created per environment

#### RDS (Databases)

Resources:
- Postgresql Database: One database is created per environment. This is the database used by the application.

#### S3 (Storage buckets)

S3 is the files storage service.

Resources:
- Buckets: Multiple buckets are created, most of them are used by the services (ex: CodePipeline store the artifact created by the CD process in a bucket). 
	Two buckets are created to serve static files as part of the web application (Front + Images).

#### CodePipeline (CI/CD)

CodePipeline is the CI/CD service. Pipeline can use multiple other services in the Developers Tools Suite (CodeBuild, CodeDeploy, etc.)

Gaïa integrates a github repository with CodePipeline and CodeBuild.
By default it will trigger a pipeline with each commit on the master branch.

![CI/CD](images/gaia_aws_pipeline.png)

Resources:
- Pipeline: One pipeline is created per environment. This pipeline fetches the code from a Github repo and forwards it to CodeBuild.
- CodeBuild: One project is created per environment. The steps of the build described in the builspec.yaml file includes the building of the docker image, the storage into the ECR repository and the deployment in the kubernetes cluster via Helm.