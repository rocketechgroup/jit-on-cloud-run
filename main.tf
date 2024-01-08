provider "google" {
  project = var.project_id
}

resource "google_compute_network" "jitaccess_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "jitaccess_subnet" {
  name          = var.subnet_name
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.jitaccess_vpc.name
}

resource "google_vpc_access_connector" "connector" {
  name          = "jit-vpc-connector"
  region        = var.region
  project       = var.project_id
  ip_cidr_range = "10.11.0.0/28"
  network       = var.vpc_name
}

# Service account for the Just-In-Time Access application
resource "google_service_account" "jitaccess" {
  account_id   = "jitaccess"
  display_name = "Just-In-Time Access"
}

# Grant the JIT service account additional permissions so that it can manage just in time privileges
resource "google_project_iam_binding" "jit_access_security_admin" {
  project = var.project_id
  role    = "roles/iam.securityAdmin"
  members = [
    "serviceAccount:${google_service_account.jitaccess.email}"
  ]
}

resource "google_project_iam_binding" "jit_access_cloudasset_viewer" {
  project = var.project_id
  role    = "roles/cloudasset.viewer"
  members = [
    "serviceAccount:${google_service_account.jitaccess.email}"
  ]
}

# Create a Cloud Run service to host the JIT service
resource "google_cloud_run_service" "jit_cloudrun_service" {
  name     = "jit-on-cloudrun"
  location = var.region
  project  = var.project_id

  metadata {
    annotations = {
      "run.googleapis.com/ingress" : "internal-and-cloud-load-balancing"
    }
  }
  template {
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" : google_vpc_access_connector.connector.name
      }
    }
    spec {
      service_account_name = google_service_account.jitaccess.email
      containers {
        image = "europe-west2-docker.pkg.dev/${var.project_id}/${var.artifact_repo}/jitaccess:latest"
        env {
          name  = "RESOURCE_SCOPE"
          value = "${var.scope_type}/${var.scope_id}"
        }
        env {
          name  = "ELEVATION_DURATION"
          value = "60"
        }
        env {
          name  = "JUSTIFICATION_HINT"
          value = "Bug or case number"
        }
        env {
          name  = "JUSTIFICATION_PATTERN"
          value = ".*"
        }
        env {
          name  = "IAP_BACKEND_SERVICE_ID"
          value = var.iap_backend_service_id
        }
      }
    }
  }
}

# Create a regional network endpoint group for the serverless NEGs.
resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  provider              = google
  name                  = "jit-serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.jit_cloudrun_service.name
  }
}

module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 9.0"

  project = var.project_id
  name    = var.lb_name

  ssl                             = true
  managed_ssl_certificate_domains = [var.domain]
  https_redirect                  = true

  backends = {
    default = {
      description = null
      groups      = [
        {
          group = google_compute_region_network_endpoint_group.serverless_neg.id
        }
      ]
      enable_cdn             = false
      security_policy        = null
      custom_request_headers = null

      iap_config = {
        enable               = true
        oauth2_client_id     = var.iap_client_id
        oauth2_client_secret = var.iap_client_secret
      }
      log_config = {
        enable      = false
        sample_rate = null
      }
    }
  }
}

# IAM policies for user / groups that gets granted access to use the JIT service via IAP
data "google_iam_policy" "iap" {
  binding {
    role    = "roles/iap.httpsResourceAccessor"
    members = split(",", var.iap_members)
  }
}

resource "google_iap_web_backend_service_iam_policy" "policy" {
  project             = var.project_id
  web_backend_service = "${var.lb_name}-backend-default"
  policy_data         = data.google_iam_policy.iap.policy_data
  depends_on          = [
    module.lb-http
  ]
}

# IAM policies for the IAP Agent service account
data "google_project" "project" {
  project_id = var.project_id
}


resource "google_project_iam_binding" "iap_binding" {
  project = data.google_project.project.project_id
  role    = "roles/run.invoker"
  members = [
    "serviceAccount:service-${data.google_project.project.number}@gcp-sa-iap.iam.gserviceaccount.com"
  ]
}

output "load-balancer-ip" {
  value = module.lb-http.external_ip
}

output "oauth2-redirect-uri" {
  value = "https://iap.googleapis.com/v1/oauth/clientIds/${var.iap_client_id}:handleRedirect"
}