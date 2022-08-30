#!/usr/bin/env bash

export PROJECT_ID="wif-sandbox"
WORKLOAD_IDENTITY_POOL_ID="my-pool"
REPO="garrettwong/auth-test"

gcloud iam service-accounts remove-iam-policy-binding "workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--project="${PROJECT_ID}" \
--role="roles/iam.workloadIdentityUser" \
--member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO}"

gcloud iam workload-identity-pools providers delete "my-provider" \
--project="${PROJECT_ID}" \
--location="global" \
--workload-identity-pool="my-pool" --quiet

gcloud iam workload-identity-pools delete "my-pool" \
--project="${PROJECT_ID}" \
--location="global" --quiet

gcloud iam service-accounts delete "workload-identity-sa@{PROJECT_ID}.iam.gserviceaccount.com" \
    --project "${PROJECT_ID}" --quiet

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
--member "serviceAccount:workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--role "roles/storage.objectAdmin" --condition=None --quiet

# secrets manager and disk create
gcloud secrets versions destroy "my-secret" --secret latest --project $PROJECT_ID
gcloud secrets delete "my-secret" --replication-policy="automatic" --project $PROJECT_ID

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
--member "serviceAccount:workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--role "roles/secretmanager.secretAccessor" --condition=None --quiet

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
--member "serviceAccount:workload-identity-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--role "roles/compute.storageAdmin" --condition=None --quiet

gsutil rm -rf gs://${PROJECT_ID}-terraform-state

# disabling services causes more headaches :/