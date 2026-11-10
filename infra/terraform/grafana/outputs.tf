output "grafana_stack_id" {
  description = "Grafana Cloud stack ID used for Cloud Provider resources."
  value       = data.grafana_cloud_stack.netrunner.id
}

output "grafana_stack_url" {
  description = "Grafana Cloud stack URL."
  value       = data.grafana_cloud_stack.netrunner.url
}

output "grafana_cloudwatch_role_arn" {
  description = "IAM role Grafana Cloud assumes for CloudWatch metric scrape."
  value       = aws_iam_role.grafana_cloudwatch.arn
}

output "grafana_aws_external_id" {
  description = "External ID currently required by the CloudWatch IAM trust policy."
  value = coalesce(
    var.grafana_aws_external_id,
    tostring(data.grafana_cloud_stack.netrunner.prometheus_user_id),
  )
}

output "cloudwatch_scrape_job_names" {
  description = "CloudWatch scrape job names in Grafana Cloud (null while enable_cloudwatch_scrape is false)."
  value = var.enable_cloudwatch_scrape ? [
    grafana_cloud_provider_aws_cloudwatch_scrape_job.netrunner_lambda[0].name,
    grafana_cloud_provider_aws_cloudwatch_scrape_job.netrunner_cloudfront[0].name,
  ] : null
}

output "enable_cloudwatch_scrape" {
  description = "Whether Cloud Provider AWS account + scrape job resources are managed."
  value       = var.enable_cloudwatch_scrape
}

output "synthetic_check_jobs" {
  description = "Synthetic Monitoring job names."
  value = [
    grafana_synthetic_monitoring_check.prod_site.job,
    grafana_synthetic_monitoring_check.stg_site.job,
  ]
}

output "netrunner_dashboard_urls" {
  description = "URLs of the Netrunner Production and Staging dashboards."
  value = {
    for env, dash in grafana_dashboard.netrunner_env : env => dash.url
  }
}

output "netrunner_folder_uid" {
  description = "UID of the Netrunner Grafana folder."
  value       = grafana_folder.netrunner.uid
}

output "cloudflare_edge_datasource_uid" {
  description = "Shared Infinity Cloudflare GraphQL data source UID (platform shared-obs)."
  value       = local.enable_cloudflare_edge ? "infinity-cloudflare" : null
}

output "github_ci_datasource_uid" {
  description = "GitHub data source UID (null if not provisioned)."
  value       = try(grafana_data_source.github[0].uid, null)
}

output "enable_cloudflare_edge" {
  description = "Whether Netrunner dashboard Cloudflare panels expect the shared Infinity DS + zoneTag."
  value       = local.enable_cloudflare_edge
}

output "enable_github_ci" {
  description = "Whether the GitHub data source is managed."
  value       = local.enable_github_ci
}
