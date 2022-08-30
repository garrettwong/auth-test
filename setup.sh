#!/usr/bin/env bash

export PROJECT_ID="wif-sandbox"
export REPO="garrettwong/auth-test" # e.g. "google/chrome"

gcloud services enable "iam.googleapis.com" "sts.googleapis.com" "iamcredentials.googleapis.com" \
--project $PROJECT_ID

gcloud iam service-accounts create "workload-identity-sa" \
--project "${PROJECT_ID}"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member "serviceAccount:workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--role "roles/storage.objectAdmin" --condition=None --quiet

# secrets manager and disk create
gcloud services enable secretmanager.googleapis.com --project $PROJECT_ID
gcloud secrets create "my-secret" --replication-policy="automatic" --project $PROJECT_ID
echo "hello-whirled" > hello.txt

gcloud secrets versions add "my-secret" --data-file="hello.txt"  --project $PROJECT_ID
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member "serviceAccount:workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--role "roles/secretmanager.secretAccessor" --condition=None --quiet

gcloud services enable compute.googleapis.com \
--project $PROJECT_ID
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member "serviceAccount:workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--role "roles/compute.storageAdmin" --condition=None --quiet

gsutil mb gs://${PROJECT_ID}-terraform-state

gcloud iam workload-identity-pools create "my-pool2" \
--project="${PROJECT_ID}" \
--location="global" \
--display-name="Demo pool"

export WORKLOAD_IDENTITY_POOL_ID=$(gcloud iam workload-identity-pools describe "my-pool2" \
    --project="${PROJECT_ID}" \
    --location="global" \
--format="value(name)")

function setup_github() {
    gcloud iam workload-identity-pools providers create-oidc "my-provider" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="my-pool2" \
    --display-name="Demo provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --issuer-uri="https://token.actions.githubusercontent.com"
    
    gcloud iam service-accounts add-iam-policy-binding "workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO}"
    
    gcloud iam workload-identity-pools providers describe "my-provider" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="my-pool2" \
    --format="value(name)"
    
    PROJECT_NUMBER=$(gcloud projects list --filter="projectId=${PROJECT_ID}" --format="value(projectNumber)")
    
    echo "Create these GITHUB ACTION Secrets at https://github.com/garrettwong/auth-test/settings/secrets/actions"
    echo "PROJECT_NUMBER: ${PROJECT_NUMBER}
POOL_ID: my-pool
PROVIDER_ID: my-provider
    SERVICE_ACCOUNT: workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com"
    
}


function setup_gcp() {
    gcloud iam workload-identity-pools providers create-oidc "domain-ext" \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool="my-pool" \
    --display-name="Provider for GCP Identities" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor" \
    --issuer-uri="https://accounts.google.com"
}

setup_github
