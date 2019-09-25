resource "random_id" "s6059_server" {
  keepers = {
    azi_id = 1
  }
  byte_length = 8
}

resource "azurerm_traffic_manager_profile" "s6059_interprovider" {
  name                   = "dt2-trafficmanager"
  resource_group_name    = "${azurerm_resource_group.rg.name}"
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${random_id.s6059_server.hex}"
    ttl           = 30
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "s6059_azureLB" {
  name                = "first"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.s6059_interprovider.name}"
  target              = "dt2-azure4.koreasouth.cloudapp.azure.com"
  type                = "externalEndpoints"
  weight              = 1
}

resource "azurerm_traffic_manager_endpoint" "s6059_awsLB" {
  name                = "second"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  profile_name        = "${azurerm_traffic_manager_profile.s6059_interprovider.name}"
  target              = "dt2-aws4.ap-northeast-2.elb.amazonaws.com"
  type                = "externalEndpoints"
  weight              = 2
}
