# Backend configuration for Terraform state
# Uncomment and configure this block after creating the GCS bucket manually

# terraform {
#   backend "gcs" {
#     bucket  = "YOUR-PROJECT-ID-tfstate"
#     prefix  = "terraform/state"
#   }
# }

# To create the bucket manually:
# gsutil mb -p YOUR-PROJECT-ID -l us-central1 gs://YOUR-PROJECT-ID-tfstate
# gsutil versioning set on gs://YOUR-PROJECT-ID-tfstate

