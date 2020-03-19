version: 0.2
phases:
  install: # Install AWS cli, kubectl (needed for Helm) and Helm
    commands:
      - apt install -y awscli
      - curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl
      - chmod +x kubectl
      - mv ./kubectl /usr/local/bin/kubectl
      - wget https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz -O helm.tar.gz; tar -xzf helm.tar.gz
      - chmod +x ./linux-amd64/helm
      - mv ./linux-amd64/helm /usr/local/bin/helm

  pre_build: # Get kube credentials from AWS
    commands:
      - aws sts get-caller-identity
      - aws eks --region ${AWS_REGION} update-kubeconfig --name ${KUBE_CLUSTER}

  build: # Build Docker image and tag it with the commit sha
    commands:
      - docker build . -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:$CODEBUILD_RESOLVED_SOURCE_VERSION -f ${DOCKERFILE_PATH}

  post_build: # Push the Docker image to the ECR
    commands:
      - $(aws ecr get-login --no-include-email --region ${AWS_REGION})
      - docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:$CODEBUILD_RESOLVED_SOURCE_VERSION
      - helm upgrade -i ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} -f ${HELM_VALUES_PATH} --set container.image.tag=$CODEBUILD_RESOLVED_SOURCE_VERSION
