# Requires org RCP to allow Grafana Labs account 008923505280 to
# sts:AssumeRole on shared-netrunner-grafana-cloudwatch-role (see README).
resource "grafana_cloud_provider_aws_account" "netrunner" {
  count    = var.enable_cloudwatch_scrape ? 1 : 0
  provider = grafana.cloud_provider

  depends_on = [
    time_sleep.grafana_iam_propagation,
    aws_iam_role.grafana_cloudwatch,
  ]

  stack_id = data.grafana_cloud_stack.netrunner.id
  role_arn = aws_iam_role.grafana_cloudwatch.arn
  name     = "netrunner"
  regions  = local.scrape_regions
}

# Phase 2 GMD trim: region specialization needs separate jobs because
# regions_subset_override is job-scoped (not per service).
resource "grafana_cloud_provider_aws_cloudwatch_scrape_job" "netrunner_lambda" {
  count    = var.enable_cloudwatch_scrape ? 1 : 0
  provider = grafana.cloud_provider

  stack_id                = data.grafana_cloud_stack.netrunner.id
  name                    = "netrunner-cloudwatch-lambda"
  aws_account_resource_id = grafana_cloud_provider_aws_account.netrunner[0].resource_id
  enabled                 = true
  export_tags             = true
  regions_subset_override = ["eu-north-1"]

  service {
    name                    = "AWS/Lambda"
    scrape_interval_seconds = 900

    metric {
      name       = "Invocations"
      statistics = ["Sum"]
    }

    metric {
      name       = "Errors"
      statistics = ["Sum"]
    }

    metric {
      name       = "Throttles"
      statistics = ["Sum"]
    }

    metric {
      name       = "Duration"
      statistics = ["Average"]
    }

    tags_to_add_to_metrics = ["Name"]
  }

  static_labels = {
    project = "netrunner"
  }
}

resource "grafana_cloud_provider_aws_cloudwatch_scrape_job" "netrunner_cloudfront" {
  count    = var.enable_cloudwatch_scrape ? 1 : 0
  provider = grafana.cloud_provider

  stack_id                = data.grafana_cloud_stack.netrunner.id
  name                    = "netrunner-cloudwatch-cloudfront"
  aws_account_resource_id = grafana_cloud_provider_aws_account.netrunner[0].resource_id
  enabled                 = true
  export_tags             = true
  regions_subset_override = ["us-east-1"]

  service {
    name                    = "AWS/CloudFront"
    scrape_interval_seconds = 900

    metric {
      name       = "Requests"
      statistics = ["Sum"]
    }

    metric {
      name       = "5xxErrorRate"
      statistics = ["Average"]
    }

    metric {
      name       = "OriginLatency"
      statistics = ["Average"]
    }

    tags_to_add_to_metrics = ["Name"]
  }

  static_labels = {
    project = "netrunner"
  }
}
