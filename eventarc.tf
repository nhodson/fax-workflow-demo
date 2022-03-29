# https://cloud.google.com/eventarc/docs/workflows/create-triggers#direct-events

resource "google_storage_bucket" "fax_workflow_ingest" {
  project       = var.project_id
  name          = "${var.project_id}-fax-workflow-ingest"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
}

# Create Service Account for triggering Workflow
resource "google_service_account" "workflow_trigger" {
  project      = var.project_id
  account_id   = "sa-workflow-trigger"
  display_name = "Workflow Trigger SA"
}

# Allow SA to invoke Workflows
resource "google_project_iam_member" "sa_wf_invoker" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.workflow_trigger.email}"
}

# Allow SA to receive events
resource "google_project_iam_member" "sa_event_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.workflow_trigger.email}"
}

# Grant the pubsub.publisher role to the Cloud Storage service account:
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_iam_member" "gcs_sa_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

module "gcloud_workflow_trigger" {
  source  = "terraform-google-modules/gcloud/google"
  version = "~> 3.0"

  platform = "linux"

  create_cmd_body  = <<-EOT
    eventarc triggers create fax-workflow-trigger \
        --project=${var.project_id} \
        --location=${var.region} \
        --destination-workflow=${google_workflows_workflow.fax_workflow.name} \
        --destination-workflow-location=${var.region} \
        --event-filters="type=google.cloud.storage.object.v1.finalized" \
        --event-filters="bucket=${google_storage_bucket.fax_workflow_ingest.name}" \
        --service-account=${google_service_account.workflow_trigger.email} \
        --impersonate-service-account=${var.terraform_service_account}
  EOT
  
  destroy_cmd_body = <<-EOT
    eventarc triggers delete fax-workflow-trigger \
        --project=${var.project_id} \
        --location=${var.region} \
        --impersonate-service-account=${var.terraform_service_account}
  EOT

  module_depends_on = [
    google_project_service.eventarc
  ]
}