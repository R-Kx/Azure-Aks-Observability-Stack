resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.prefix}-${var.environment}"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                      = "aks-${var.prefix}-${var.environment}"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  dns_prefix                = "aksstore"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "lxpool"
    node_count = 1
    vm_size    = "Standard_D2s_v3"
    os_sku     = "Ubuntu"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  windows_profile {
    admin_username = var.win_admin_username
    admin_password = var.win_admin_password
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }

  lifecycle {
    ignore_changes = [
      image_cleaner_interval_hours,
      default_node_pool[0].upgrade_settings,
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "winpool" {
  name                  = "win"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D2s_v3"
  node_count            = 1
  os_type               = "Windows"
  os_sku                = "Windows2022"

  lifecycle {
    ignore_changes = [
      windows_profile,
      upgrade_settings
    ]
  }
}

data "http" "aks_store_manifest" {
  url = "https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml"
}

data "kubectl_file_documents" "manifest_docs" {
  content = data.http.aks_store_manifest.response_body
}

resource "kubectl_manifest" "aks_store_app" {
  for_each         = data.kubectl_file_documents.manifest_docs.manifests
  yaml_body        = each.value
  wait_for_rollout = false

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_kubernetes_cluster_node_pool.winpool
  ]
}
