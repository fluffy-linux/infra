# A monthly budget for the project, with email alerts to the billing
# account's admins (no addresses in the repository): at 50, 80 and 100% of
# actual spend, and when the month's forecast passes 100%.  It only alerts;
# GCP does not stop spending at a budget.

variable "billing_account" {
  description = "The billing account the project is linked to (gcloud billing projects describe <project>).  Set in terraform.tfvars, which is not committed."
  type        = string
}

variable "budget_usd" {
  description = "The monthly budget, in US dollars."
  type        = number
  default     = 50
}

resource "google_billing_budget" "ci" {
  billing_account = var.billing_account
  display_name    = "fluffy-linux monthly"

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.8
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [google_project_service.services]
}

data "google_project" "this" {
  project_id = var.project
}

# Where Cloud Billing exports the project's costs, for queries by service
# and SKU.  The export itself can only be turned on in the Console
# (Billing > Billing export > BigQuery export: standard usage cost, and
# detailed usage cost, to project fluffy-linux, dataset fluffy_billing);
# the Cloud Billing API has no call for it.  It records costs from then on.
resource "google_bigquery_dataset" "billing" {
  dataset_id    = "fluffy_billing"
  friendly_name = "Cloud Billing export"
  description   = "Cloud Billing's export of fluffy-linux's costs (standard and detailed usage)."
  location      = "US"
  depends_on    = [google_project_service.services]
}
