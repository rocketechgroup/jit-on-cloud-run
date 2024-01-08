# Jit on cloud run

Just-In-Time (JIT) privileged access is a method for managing access to Google Cloud projects in a more secure and
efficient manner. It's an approach that aligns with the principle of least privilege, granting users only the access
they need to perform specific tasks and only when they need it. This method helps reduce risks, such as accidental
modifications or deletions of resources, and creates an audit trail for tracking why and when privileged access is
activated.

The Just-In-Time Access tool, an open-source application created by Google. It supports this model by allowing
administrators to grant eligible access to users or groups. This access is not immediately available; users must
actively activate it and provide a justification. The activated access then automatically expires after a short period.

Although the official documentation suggest deploying it to AppEngine, due to its lacking of support on VPC Service
Controls (VPC SC), I'll focus on how it runs on Cloud Run instead so that it works for small organisations and large
enterprises.

## Build the image
> Assuming you've already checked out https://github.com/GoogleCloudPlatform/jit-access into a working directory `../jit-access`

Go to your `jit-access` working directory, create a `cloudbuild.yaml` file with the following content
```
steps:
  # Build the Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args: [ 'build', '-t', 'europe-west2-docker.pkg.dev/${_PROJECT_ID}/${_REPO_NAME}/jitaccess:latest', '.' ]

  # Push the Docker image to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: [ 'push', 'europe-west2-docker.pkg.dev/${_PROJECT_ID}/${_REPO_NAME}/jitaccess:latest' ]
```
Then run 
```
gcloud builds submit --substitutions _PROJECT_ID=${PROJECT_ID},_REPO_NAME=${AF_REPO_NAME}
```

## Deployment

```
export PROJECT_ID=<your gcp project id>
export REGION=<region>
export DOMAIN=<your domain or sub-domain>
export LB_NAME=<name of the load balancer>
export IAP_CLIENT_ID=<iap client id>
export IAP_CLIENT_SECRET=<iap client secret>
export IAP_MEMBERS=<a list of users or groups>
export SCOPE_TYPE=<type of scope, see terraform variables.tf>
export SCOPE_ID=<ID, see terraform variables.tf>
export ARTIFACT_REPO=<artifact repository id>
export IAP_BACKEND_SERVICE_ID=$(gcloud compute backend-services describe jit-sandbox-lb-backend-default --global --format 'value(id)')

terraform apply -var project_id=${PROJECT_ID} \
    -var region=${REGION} \
    -var domain=${DOMAIN} \
    -var lb_name=${LB_NAME} \
    -var iap_client_id=${IAP_CLIENT_ID} \
    -var iap_client_secret=${IAP_CLIENT_SECRET} \
    -var iap_members=${IAP_MEMBERS} \
    -var scope_type=${SCOPE_TYPE} \
    -var scope_id=${SCOPE_ID} \
    -var artifact_repo=${ARTIFACT_REPO} \
    -var iap_backend_service_id=${IAP_BACKEND_SERVICE_ID}
```

## Credit
Credit to https://github.com/ahmetb/cloud-run-iap-terraform-demo for creating an amazing demo on how to do the whole IAP deployment via Terraform