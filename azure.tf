resource "azurerm_resource_group" "s6059-rg" {
  name     = "s6059-rg"
  location = "koreasouth"
}

variable "application_port" {
   description = "The port that you want to expose to the external load balancer"
   default     = 80
}
resource "azurerm_network_security_group" "s6059-secGroup" {
    name = "s6059-sg"
    location = "koreasouth"
    resource_group_name ="${azurerm_resource_group.s6059-rg.name}"

    security_rule {
        name ="SSH"
        priority = "1001"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "HTTP"
        priority = "2001"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "80"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_virtual_network" "s6059-vnetwork" {
    name = "s6059-vnet"
    address_space = ["192.168.2.0/24"]
    location = "koreasouth"
    resource_group_name = "${azurerm_resource_group.s6059-rg.name}"
    
}
resource "azurerm_subnet" "s6059-mysubnet" {
    name = "s6059-subnet"
    resource_group_name = "${azurerm_resource_group.s6059-rg.name}"
    virtual_network_name = "${azurerm_virtual_network.s6059-vnetwork.name}"
#    network_security_group_id = "${azurerm_network_security_group.s6059-secGroup.id}"
    address_prefix = "192.168.2.0/25"
}
resource "azurerm_public_ip" "s6059-publicdomainip" {
    name                         = "s6059-publicdomainip"
    location                     = "koreasouth"
    resource_group_name          = "${azurerm_resource_group.s6059-rg.name}"
    allocation_method            = "Static"
    domain_name_label            = "s6059-azure4"
}

resource "azurerm_public_ip" "s6059-rdpip" {
    name = "s6059-rdpip${count.index}"
    location = "koreasouth"
    resource_group_name = "${azurerm_resource_group.s6059-rg.name}"
    allocation_method = "Dynamic"
    count = 2
}

resource "azurerm_lb" "s6059-lb" {
  resource_group_name = "${azurerm_resource_group.s6059-rg.name}"
  name                = "s6059-lb"
  location            = "koreasouth"
  
  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.s6059-publicdomainip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "s6059-bp" {
    resource_group_name = "${azurerm_resource_group.s6059-rg.name}"
    loadbalancer_id     = "${azurerm_lb.s6059-lb.id}"
    name                = "s6059-bp"
}

resource "azurerm_network_interface_backend_address_pool_association" "s6059-bpAS" {
  count = 2
  network_interface_id = "${element(azurerm_network_interface.s6059-nic.*.id, count.index)}"
  ip_configuration_name   = "ipconfig${count.index}"														 
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.s6059-bp.id}"
}

resource "azurerm_lb_probe" "s6059-lb_probe" {
  resource_group_name = "${azurerm_resource_group.s6059-rg.name}"															  
  loadbalancer_id     = "${azurerm_lb.s6059-lb.id}"
  name                = "s6059-lb-probe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2									 
}

resource "azurerm_lb_rule" "s6059-lb_rule" {								
  resource_group_name            = "${azurerm_resource_group.s6059-rg.name}"
  loadbalancer_id                = "${azurerm_lb.s6059-lb.id}"
  name                           = "s6059-lb-rule"
  protocol                       = "tcp"
  frontend_port                  = "${var.application_port}"
  backend_port                   = "${var.application_port}"
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.s6059-bp.id}"
  idle_timeout_in_minutes        = 5
  probe_id                       = "${azurerm_lb_probe.s6059-lb_probe.id}"
  depends_on                     = ["azurerm_lb_probe.s6059-lb_probe"]
}

resource "azurerm_network_interface" "s6059-nic" {
  name                = "s6059-nic${count.index}"
  location            = "koreasouth"
  resource_group_name = "${azurerm_resource_group.s6059-rg.name}"
  network_security_group_id = "${azurerm_network_security_group.s6059-secGroup.id}"  
  count               = 2

  ip_configuration {
    name                                    = "ipconfig${count.index}"
    subnet_id                               = "${azurerm_subnet.s6059-mysubnet.id}"
    private_ip_address_allocation           = "Dynamic"    
    public_ip_address_id = "${length(azurerm_public_ip.s6059-rdpip.*.id) > 0 ? element(concat(azurerm_public_ip.s6059-rdpip.*.id, list("")), count.index) : ""}"	
  }
}

resource "azurerm_availability_set" "s6059-avset" {
  name                         = "s6059-avset"
  location                     = "koreasouth"
  resource_group_name          = "${azurerm_resource_group.s6059-rg.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_virtual_machine" "s6059-vm" {
  name                  = "s6059-vm${count.index}"
  location              = "koreasouth"
  resource_group_name   = "${azurerm_resource_group.s6059-rg.name}"
 availability_set_id   = "${azurerm_availability_set.s6059-avset.id}"
  network_interface_ids = ["${element(azurerm_network_interface.s6059-nic.*.id, count.index)}"]
  vm_size = "Standard_D1_v2"
  count = 2
  storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.4"
        version   = "latest"
    }  
  storage_os_disk {
        name = "s6059-dist${count.index}"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
  }

  os_profile {
        computer_name = "s6059-vm${count.index}"
        admin_username = "azuredt2"
        admin_password= "Jsgood414159!"
  }
  os_profile_linux_config {
        disable_password_authentication = false											 
  }
}

