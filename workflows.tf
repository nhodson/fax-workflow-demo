resource "google_service_account" "workflows" {
  project      = var.project_id
  account_id   = "workflows-sa"
  display_name = "Workflows SA"
}

resource "google_storage_bucket_iam_member" "workflow_sa" {
  bucket = google_storage_bucket.fax_workflow_ingest.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.workflows.email}"
}

# Allow workflow to call Doc AI
resource "google_project_iam_member" "docai_apiuser" {
  project = var.project_id
  role    = "roles/documentai.apiUser"
  member  = "serviceAccount:${google_service_account.workflows.email}"
}

# Allow workflow sys.log step
resource "google_project_iam_member" "logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflows.email}"
}

resource "google_project_iam_member" "service_usage" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.workflows.email}"
}

resource "google_workflows_workflow" "fax_workflow" {
  project         = var.project_id
  name            = "fax-workflow"
  region          = var.region
  description     = "description goes here"
  service_account = google_service_account.workflows.id
  source_contents = templatefile("${path.module}/workflow.yaml.tpl", {
    projectId             = var.project_id
    region                = var.region
    processorId           = var.docai_processor_id
  })

  depends_on = [google_project_service.workflows]
}

resource "google_storage_bucket" "docai_output" {
  project       = var.project_id
  name          = "${var.project_id}-docai-output"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
}

# Allow workflow to access Doc AI output location
resource "google_storage_bucket_iam_member" "workflow_sa_outputs" {
  bucket = google_storage_bucket.docai_output.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.workflows.email}"
}