data "azurerm_subscription" "current" {}

resource "azurerm_monitor_action_group" "ag" {
  name                = "ag-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "aks-alerts"

  email_receiver {
    name                    = "admin-email"
    email_address           = var.admin_email
    use_common_alert_schema = true
  }
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "pod_issues_alert" {
  name                 = "alert-aks-pod-issues"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  scopes               = [azurerm_log_analytics_workspace.law.id]
  description          = "Alert triggers when AKS pods enter Failed/Pending state or undergo restarts."
  severity             = 1
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"

  criteria {
    query = <<-QUERY
      KubePodInventory
      | where TimeGenerated > ago(5m)
      | where PodStatus in ("Failed", "Pending", "Unknown") or PodRestartCount > 0
      | summarize PodCount = count() by PodLabel, ControllerName, Namespace
    QUERY

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.ag.id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "node_issues_alert" {
  name                 = "alert-aks-node-issues"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  scopes               = [azurerm_log_analytics_workspace.law.id]
  description          = "Alert triggers when an AKS node becomes NotReady, Unknown, or experiences Memory/Disk pressure."
  severity             = 1
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"

  criteria {
    query = <<-QUERY
      KubeNodeInventory
      | where TimeGenerated > ago(5m)
      | where Status != "Ready"
    QUERY

    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.ag.id]
  }
}

resource "azurerm_portal_dashboard" "aks_dashboard" {
  name                = "dash-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  dashboard_properties = templatefile("${path.module}/azure-dashboard.json.tftpl", {
    resource_group  = azurerm_resource_group.rg.name
    subscription_id = data.azurerm_subscription.current.subscription_id
    cluster_name    = azurerm_kubernetes_cluster.aks.name
    #workspace_name = azurerm_log_analytics_workspace.law.name
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  })
}

resource "azurerm_application_insights_workbook" "aks_diag_workbook" {
  name                = uuidv5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "aks-hw3-dev-workbook-${var.prefix}-${var.environment}")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  display_name        = "aks-diagnostics-insights-${var.prefix}-${var.environment}"
  category            = "workbook"

  data_json = templatefile("${path.module}/azure-workbook.json.tftpl", {
    cluster_name               = azurerm_kubernetes_cluster.aks.name
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  })
}
