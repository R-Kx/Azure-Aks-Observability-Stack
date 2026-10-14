

resource "azurerm_monitor_workspace" "amw" {
  name                = "amw-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "dce-${var.prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "Linux"
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                        = "dcr-prometheus-${var.prefix}-${var.environment}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.amw.id
      name               = "MonitoringAccount"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusMetric"
    }
  }

  description = "Scrapes CPU, Memory, Node/Pod status, and Container metrics from AKS"
}

resource "azurerm_monitor_data_collection_rule_association" "asso_dcr" {
  name                    = "asso-dcr-prometheus-${var.prefix}-${var.environment}"
  target_resource_id      = azurerm_kubernetes_cluster.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
}

resource "azurerm_role_assignment" "dcr_publisher" {
  scope                = azurerm_monitor_data_collection_rule.dcr.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

resource "azurerm_dashboard_grafana" "grafana" {
  name                  = "amg-${var.prefix}-${var.environment}"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  sku                   = "Standard"
  grafana_major_version = "12"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.amw.id
  }
}

resource "azurerm_role_assignment" "grafana_amw_reader" {
  scope                = azurerm_monitor_workspace.amw.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_law_reader" {
  scope                = azurerm_log_analytics_workspace.law.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_admin" {
  scope                = azurerm_dashboard_grafana.grafana.id
  role_definition_name = "Grafana Admin"
  principal_id         = var.principal_id
  principal_type       = "User"
}

resource "grafana_dashboard" "aks_monitoring" {
  config_json = templatefile("${path.module}/grafana-dash-hw3.json.tftpl", {
    DS_PROMETHEUS = azurerm_monitor_workspace.amw.name
  })

  depends_on = [
    azurerm_role_assignment.grafana_admin,
    azurerm_role_assignment.grafana_amw_reader
  ]
}

output "grafana_url" {
  value       = azurerm_dashboard_grafana.grafana.endpoint
  description = "The Web URL endpoint to access Azure Managed Grafana UI"
}

