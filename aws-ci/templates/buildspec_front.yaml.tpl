version: 0.1
phases:
  pre_build:
    commands:
      - echo Installing source NPM dependencies...
      - cd ${front_dir} && npm install

  build:
    commands:
      - echo Build started on `date`
      - cd ${front_dir} && npm run build

  post_build:
    commands:
      # copy the contents of /build to S3
      - aws s3 cp --recursive --acl public-read ${front_dir}/dist s3://${DeployBucket}/ 
      # set the cache-control headers for index.html to prevent
      # browser caching
      - >
        aws s3 cp --acl public-read 
        --cache-control="max-age=0, no-cache, no-store, must-revalidate" 
        ${front_dir}/dist/index.html s3://${DeployBucket}/
