##############################################################################################################
#
#
# FortiGate Active/Passive Load Balanced HA pair of VMs for resilience
# Terraform deployment template for Oracle Cloud
#
##############################################################################################################

##############################################################################################################
## VCN
##############################################################################################################

resource "oci_core_virtual_network" "vcn" {
  count          = var.create_network ? 1 : 0
  cidr_block     = var.vcn
  compartment_id = var.compartment_ocid
  display_name   = "${var.PREFIX}-vcn"
  dns_label      = "fgthub"
}

resource "oci_core_internet_gateway" "igw" {
  count          = var.create_network ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.PREFIX}-igw"
  vcn_id         = oci_core_virtual_network.vcn[0].id
}



##############################################################################################################
## UNTRUSTED NETWORK
##############################################################################################################

resource "oci_core_subnet" "untrusted_subnet" {
  count             = var.create_network ? 1 : 0
  cidr_block        = var.subnet["2"]
  display_name      = "${var.PREFIX}-untrusted"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.vcn[0].id
  route_table_id    = oci_core_route_table.untrusted_routetable[0].id
  security_list_ids = ["${oci_core_virtual_network.vcn[0].default_security_list_id}", "${oci_core_security_list.untrusted_security_list[0].id}"]
  dhcp_options_id   = oci_core_virtual_network.vcn[0].default_dhcp_options_id
  dns_label         = "fgtuntrusted"
}

resource "oci_core_route_table" "untrusted_routetable" {
  count          = var.create_network ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn[0].id
  display_name   = "${var.PREFIX}-untrusted-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw[0].id
  }
}

resource "oci_core_security_list" "untrusted_security_list" {
  count          = var.create_network ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn[0].id
  display_name   = "${var.PREFIX}-untrusted-security-list"

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  // allow inbound http (port 80) traffic
  # ingress_security_rules {
  #   protocol = "6" // tcp
  #   source   = "0.0.0.0/0"

  #   tcp_options {
  #     min = 80
  #     max = 80
  #   }
  # }

  // allow inbound http (port 443) traffic
  ingress_security_rules {
    protocol = "6" // tcp
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }

  // allow inbound http (port 8443) traffic
  # ingress_security_rules {
  #   protocol = "6" // tcp
  #   source   = "0.0.0.0/0"

  #   tcp_options {
  #     min = 8443
  #     max = 8443
  #   }
  # }

  // allow inbound ssh traffic
  ingress_security_rules {
    protocol  = "6" // tcp
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol  = "6" // tcp
    source    = "172.16.140.0/28"
    stateless = false

    tcp_options {
      min = 8008
      max = 8008
    }
  }

}

##############################################################################################################
## TRUSTED NETWORK
##############################################################################################################

resource "oci_core_subnet" "trusted_subnet" {
  count                      = var.create_network ? 1 : 0
  cidr_block                 = var.subnet["3"]
  display_name               = "${var.PREFIX}-trusted"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.vcn[0].id
  security_list_ids          = ["${oci_core_virtual_network.vcn[0].default_security_list_id}", "${oci_core_security_list.trusted_security_list[0].id}"]
  dhcp_options_id            = oci_core_virtual_network.vcn[0].default_dhcp_options_id
  dns_label                  = "fgttrusted"
  prohibit_public_ip_on_vnic = true
}

// route table attachment
resource "oci_core_route_table_attachment" "trust_route_table_attachment" {
  count          = var.create_network ? 1 : 0
  subnet_id      = oci_core_subnet.trusted_subnet[0].id
  route_table_id = oci_core_route_table.trusted_routetable[0].id
}

resource "oci_core_security_list" "trusted_security_list" {
  count          = var.create_network ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn[0].id
  display_name   = "fgt-trusted-security-list"

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  // allow inbound all 
  ingress_security_rules {
    protocol = "all" // tcp
    source   = "0.0.0.0/0"
  }
}


# // Add DRG route distribution for OCI VCN
# resource "oci_core_drg_route_distribution" "drg_spoke_route_distribution" {
#   // Required
#   drg_id = var.drg_id
#   distribution_type = "IMPORT"
#   // optional
#   display_name = "${var.PREFIX}-drg-spoke-route-distribution"
# }
# resource "oci_core_drg_route_distribution_statement" "drg_spoke_route_distribution_statements" {
#   // Required
#   drg_route_distribution_id = oci_core_drg_route_distribution.drg_spoke_route_distribution.id
#   action = "ACCEPT"
#   match_criteria {}
#   priority = 1
# }

resource "oci_core_route_table" "trusted_routetable" {
  count          = var.create_network ? 1 : 0
  depends_on     = [oci_core_vnic_attachment.vnic_attach_trusted_fgt_a]
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn[0].id
  display_name   = "fgt-trusted-routetable"


  //Route to fortigate
  route_rules {
    description       = "Default Route to FGT int"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_private_ip.trusted_float_fgt_a.id
  }

  //Route to Other VCNs This is commented out, but you will need to add this in order for this to work
  # route_rules {
  #   description       = "Route to other spoke"
  #   destination       = var.vcn_cidr_spoke1
  #   destination_type  = "CIDR_BLOCK"
  #   network_entity_id = oci_core_drg.drg.id
  # }
}

##############################################################################################################
## HB-DEV NETWORK
##############################################################################################################

resource "oci_core_subnet" "hbdev_subnet" {
  count                      = var.create_network ? 1 : 0
  cidr_block                 = var.subnet["4"]
  display_name               = "${var.PREFIX}-hbdev"
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_virtual_network.vcn[0].id
  security_list_ids          = ["${oci_core_virtual_network.vcn[0].default_security_list_id}", "${oci_core_security_list.hbdev_security_list[0].id}"]
  dhcp_options_id            = oci_core_virtual_network.vcn[0].default_dhcp_options_id
  dns_label                  = "fgthbdev"
  prohibit_public_ip_on_vnic = true
}
resource "oci_core_security_list" "hbdev_security_list" {
  count          = var.create_network ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn[0].id
  display_name   = "fgt-hbdev-security-list"

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  // allow inbound all 
  ingress_security_rules {
    protocol = "all" // tcp
    source   = "0.0.0.0/0"
  }
}

##############################################################################################################
## Management NETWORK
##############################################################################################################

resource "oci_core_subnet" "management_subnet" {
  count             = var.create_network ? 1 : 0
  cidr_block        = var.subnet["5"]
  display_name      = "${var.PREFIX}-management"
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.vcn[0].id
  route_table_id    = oci_core_route_table.management_routetable[0].id
  security_list_ids = ["${oci_core_virtual_network.vcn[0].default_security_list_id}", "${oci_core_security_list.management_security_list[0].id}"]
  dhcp_options_id   = oci_core_virtual_network.vcn[0].default_dhcp_options_id
  dns_label         = "fgtmanagement"
}

resource "oci_core_route_table" "management_routetable" {
  count          = var.create_network ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn[0].id
  display_name   = "${var.PREFIX}-management-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw[0].id
  }
}

resource "oci_core_security_list" "management_security_list" {
  count          = var.create_network ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.vcn[0].id
  display_name   = "${var.PREFIX}-management-security-list"

  // allow outbound tcp traffic on all ports
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }


  // allow inbound http (port 443) traffic
  ingress_security_rules {
    protocol = "6" // tcp
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }

  // allow inbound http (port 8443) traffic
  ingress_security_rules {
    protocol = "6" // tcp
    source   = "0.0.0.0/0"

    tcp_options {
      min = 8443
      max = 8443
    }
  }

  // allow inbound ssh traffic
  ingress_security_rules {
    protocol  = "6" // tcp
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {
      min = 22
      max = 22
    }
  }
}



##############################################################################################################
## DRG connections
##############################################################################################################


# resource "oci_core_drg_route_table" "drg_hub_route_table" {
#   drg_id = var.drg_id
#   display_name = "${var.PREFIX}-drg-hub-route-table"
#   import_drg_route_distribution_id = oci_core_drg_route_distribution.drg_hub_route_distribution.id
# }

# //Create DRG attachment for OCI VCN
# resource "oci_core_drg_attachment" "drg_hub_attachment" {
#   drg_id = var.drg_id
#   network_details {
#     id = oci_core_virtual_network.vcn.id
#     type = "VCN"
#     route_table_id = oci_core_route_table.vcn_routetable.id
#     vcn_route_type = var.drg_attachment_network_details_vcn_route_type
#   }
#   display_name = "${var.PREFIX}-drg-hub-attachment"
#   drg_route_table_id = oci_core_drg_route_table.drg_hub_route_table.id
# }

# // Add DRG route distribution for OCI VCN
# resource "oci_core_drg_route_distribution" "drg_hub_route_distribution" {
#   // Required
#   drg_id = var.drg_id
#   distribution_type = "IMPORT"
#   // optional
#   display_name = "${var.PREFIX}-drg-hub-route-distribution"
# }
# resource "oci_core_drg_route_distribution_statement" "drg_hub_route_distribution_statements" {
#   // Required
#   drg_route_distribution_id = oci_core_drg_route_distribution.drg_hub_route_distribution.id
#   action = "ACCEPT"
#   match_criteria {}
#   priority = 1
# }

##############################################################################################################
// route table
##############################################################################################################

# resource "oci_core_route_table" "vcn_routetable" {
#   depends_on     = [oci_core_vnic_attachment.vnic_attach_trusted_fgt_a]
#   compartment_id = var.compartment_ocid
#   vcn_id         = oci_core_virtual_network.vcn.id
#   display_name   = "fgt-vcn-routetable"


#   //Route to fortigate
#   route_rules {
#     description       = "Default Route to FGT int"
#     destination       = "0.0.0.0/0"
#     destination_type  = "CIDR_BLOCK"
#     network_entity_id = data.oci_core_private_ips.nlb_trusted_private_ip.private_ips[0].id
#   }
# }



##############################################################################################################
## FortiGate A
##############################################################################################################

// create oci instance for active
resource "oci_core_instance" "vm_fgt_a" {
  depends_on = [oci_core_vnic_attachment.vnic_attach_hbdev_fgt_b]

  availability_domain = lookup(data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain - 1], "name")
  compartment_id      = var.compartment_ocid
  display_name        = "${var.PREFIX}-fgta"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = endswith(var.instance_shape, ".Flex") ? [1] : []
    content {
      memory_in_gbs = var.instance_memory_in_gbs
      ocpus         = var.instance_ocpus
    }
  }

  create_vnic_details {
    subnet_id        = local.management_subnet_id
    display_name     = "${var.PREFIX}-fgta-vnic-management"
    assign_public_ip = true
    hostname_label   = "${var.PREFIX}-fgta-vnic-management"
    private_ip       = var.fgt_ipaddress_a["5"]
  }

  launch_options {
    //    network_type = "PARAVIRTUALIZED"
    network_type = "VFIO"
  }

  source_details {
    source_type             = "image"
    source_id               = local.mp_listing_resource_id // marketplace listing
    boot_volume_size_in_gbs = "50"
  }

  // Required for bootstrap
  // Commnet out the following if you use the feature.
  metadata = {
    user_data = base64encode(local.custom_data_fgt_a)
  }

  timeouts {
    create = "60m"
  }
}

resource "oci_core_vnic_attachment" "vnic_attach_untrusted_fgt_a" {
  depends_on   = [oci_core_instance.vm_fgt_a]
  instance_id  = oci_core_instance.vm_fgt_a.id
  display_name = "${var.PREFIX}-fgta-vnic-untrusted"

  create_vnic_details {
    subnet_id              = local.untrusted_subnet_id
    display_name           = "${var.PREFIX}-fgta-vnic-untrusted"
    assign_public_ip       = true
    skip_source_dest_check = true
    private_ip             = var.fgt_ipaddress_a["2"]
  }
}

resource "oci_core_private_ip" "untrusted_float_fgt_a" {
  vnic_id      = oci_core_vnic_attachment.vnic_attach_untrusted_fgt_a.vnic_id
  display_name = "${var.PREFIX}-fgta-vnic-untrusted-float"
  ip_address   = var.unt_float_ipaddress["2"]
}

resource "oci_core_public_ip" "untrusted_float_public_ip" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "${var.PREFIX}-untrusted-float-public-ip"
  private_ip_id  = oci_core_private_ip.untrusted_float_fgt_a.id
}

resource "oci_core_vnic_attachment" "vnic_attach_trusted_fgt_a" {
  depends_on   = [oci_core_vnic_attachment.vnic_attach_untrusted_fgt_a]
  instance_id  = oci_core_instance.vm_fgt_a.id
  display_name = "${var.PREFIX}-fgta-vnic-trusted"

  create_vnic_details {
    subnet_id              = local.trusted_subnet_id
    display_name           = "${var.PREFIX}-fgta-vnic-trusted"
    assign_public_ip       = false
    skip_source_dest_check = true
    private_ip             = var.fgt_ipaddress_a["3"]
  }
}

resource "oci_core_private_ip" "trusted_float_fgt_a" {
  vnic_id      = oci_core_vnic_attachment.vnic_attach_trusted_fgt_a.vnic_id
  display_name = "${var.PREFIX}-fgta-vnic-trusted-float"
  ip_address   = var.tr_float_ipaddress["3"]
}

resource "oci_core_vnic_attachment" "vnic_attach_hbdev_fgt_a" {
  depends_on   = [oci_core_vnic_attachment.vnic_attach_trusted_fgt_a]
  instance_id  = oci_core_instance.vm_fgt_a.id
  display_name = "${var.PREFIX}-fgta-vnic-hbdev"

  create_vnic_details {
    subnet_id              = local.hbdev_subnet_id
    display_name           = "${var.PREFIX}-fgta-vnic-hbdev"
    assign_public_ip       = false
    skip_source_dest_check = true
    private_ip             = var.fgt_ipaddress_a["4"]
  }
}


resource "oci_core_volume" "volume_fgt_a" {
  availability_domain = lookup(data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain - 1], "name")
  compartment_id      = var.compartment_ocid
  display_name        = "${var.PREFIX}-fgta-volume"
  size_in_gbs         = var.volume_size
}

// Use paravirtualized attachment for now.
resource "oci_core_volume_attachment" "volume_attach_fgt_a" {
  attachment_type = "paravirtualized"
  //attachment_type = "iscsi"   //  user needs to manually add the iscsi disk on fos after
  instance_id = oci_core_instance.vm_fgt_a.id
  volume_id   = oci_core_volume.volume_fgt_a.id
}

// Use for bootstrapping cloud-init
locals {
  custom_data_fgt_a = templatefile("${path.module}/customdata.tpl", {
    fgt_vm_name           = "${var.PREFIX}-fgta"
    fgt_license_file      = "${var.fgt_byol_license_a == "" ? var.fgt_byol_license_a : (fileexists(var.fgt_byol_license_a) ? file(var.fgt_byol_license_a) : var.fgt_byol_license_a)}"
    fgt_license_flexvm    = var.fgt_byol_flexvm_license_a
    port1_ip              = var.fgt_ipaddress_a["5"]
    port1_mask            = var.subnetmask["5"]
    unt_float             = var.unt_float_ipaddress["2"]
    tr_float              = var.tr_float_ipaddress["3"]
    port2_ip              = var.fgt_ipaddress_a["2"]
    port2_mask            = var.subnetmask["2"]
    port3_ip              = var.fgt_ipaddress_a["3"]
    port3_mask            = var.subnetmask["3"]
    port4_ip              = var.fgt_ipaddress_a["4"]
    port4_mask            = var.subnetmask["4"]
    peer_hbdev_ip         = var.fgt_ipaddress_b["4"]
    ha_netmask            = var.ha_netmask
    untrusted_gateway_ip  = local.untrusted_gateway_ip
    trusted_gateway_ip    = local.trusted_gateway_ip
    management_gateway_ip = local.management_gateway_ip
    priority              = 255
    fgt_password          = var.fgt_password
    vcn_cidr              = var.vcn
  })
}

##############################################################################################################
## FortiGate B
##############################################################################################################

// create oci instance for passive

resource "oci_core_instance" "vm_fgt_b" {
  depends_on = [oci_core_internet_gateway.igw]

  availability_domain = lookup(data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain2 - 1], "name")
  compartment_id      = var.compartment_ocid
  display_name        = "${var.PREFIX}-fgtb"
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = endswith(var.instance_shape, ".Flex") ? [1] : []
    content {
      memory_in_gbs = var.instance_memory_in_gbs
      ocpus         = var.instance_ocpus
    }
  }

  create_vnic_details {
    subnet_id        = local.management_subnet_id
    display_name     = "${var.PREFIX}-fgtb-vnic-management"
    assign_public_ip = true
    hostname_label   = "${var.PREFIX}-fgtb-vnic-management"
    private_ip       = var.fgt_ipaddress_b["5"]
  }

  launch_options {
    network_type = "VFIO"
  }

  source_details {
    source_type             = "image"
    source_id               = local.mp_listing_resource_id // marketplace listing
    boot_volume_size_in_gbs = "50"
  }

  // Required for bootstrap
  // Commnet out the following if you use the feature.
  metadata = {
    user_data = "${base64encode(local.custom_data_fgt_b)}"
  }

  timeouts {
    create = "60m"
  }
}

resource "oci_core_vnic_attachment" "vnic_attach_untrusted_fgt_b" {
  depends_on   = [oci_core_instance.vm_fgt_b]
  instance_id  = oci_core_instance.vm_fgt_b.id
  display_name = "${var.PREFIX}-fgtb-vnic-untrusted"

  create_vnic_details {
    subnet_id              = local.untrusted_subnet_id
    display_name           = "${var.PREFIX}-fgtb-vnic-untrusted"
    assign_public_ip       = true
    skip_source_dest_check = true
    private_ip             = var.fgt_ipaddress_b["2"]
  }
}

resource "oci_core_vnic_attachment" "vnic_attach_trusted_fgt_b" {
  depends_on   = [oci_core_vnic_attachment.vnic_attach_untrusted_fgt_b]
  instance_id  = oci_core_instance.vm_fgt_b.id
  display_name = "${var.PREFIX}-fgtb-vnic-trusted"

  create_vnic_details {
    subnet_id              = local.trusted_subnet_id
    display_name           = "${var.PREFIX}-fgtb-vnic-trust"
    assign_public_ip       = false
    skip_source_dest_check = true
    private_ip             = var.fgt_ipaddress_b["3"]
  }
}

resource "oci_core_vnic_attachment" "vnic_attach_hbdev_fgt_b" {
  depends_on   = [oci_core_vnic_attachment.vnic_attach_trusted_fgt_b]
  instance_id  = oci_core_instance.vm_fgt_b.id
  display_name = "${var.PREFIX}-fgtb-vnic-hbdev"

  create_vnic_details {
    subnet_id              = local.hbdev_subnet_id
    display_name           = "${var.PREFIX}-fgtb-vnic-trusted"
    assign_public_ip       = false
    skip_source_dest_check = true
    private_ip             = var.fgt_ipaddress_b["4"]
  }
}


resource "oci_core_volume" "volume_fgt_b" {
  availability_domain = lookup(data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain2 - 1], "name")
  compartment_id      = var.compartment_ocid
  display_name        = "${var.PREFIX}-fgtb-volume"
  size_in_gbs         = var.volume_size
}

resource "oci_core_volume_attachment" "volume_attach_fgt_b" {
  attachment_type = "paravirtualized"
  //attachment_type = "iscsi"   //  user needs to manually add the iscsi disk on fos after
  instance_id = oci_core_instance.vm_fgt_b.id
  volume_id   = oci_core_volume.volume_fgt_b.id
}

// Use for bootstrapping cloud-init
locals {
  custom_data_fgt_b = templatefile("${path.module}/customdata.tpl", {
    fgt_vm_name           = "${var.PREFIX}-fgtb"
    fgt_license_file      = "${var.fgt_byol_license_b == "" ? var.fgt_byol_license_b : (fileexists(var.fgt_byol_license_b) ? file(var.fgt_byol_license_b) : var.fgt_byol_license_b)}"
    fgt_license_flexvm    = var.fgt_byol_flexvm_license_b
    port1_ip              = var.fgt_ipaddress_b["5"]
    port1_mask            = var.subnetmask["5"]
    unt_float             = var.unt_float_ipaddress["2"]
    tr_float              = var.tr_float_ipaddress["3"]
    port2_ip              = var.fgt_ipaddress_b["2"]
    port2_mask            = var.subnetmask["2"]
    port3_ip              = var.fgt_ipaddress_b["3"]
    port3_mask            = var.subnetmask["3"]
    port4_ip              = var.fgt_ipaddress_b["4"]
    port4_mask            = var.subnetmask["4"]
    peer_hbdev_ip         = var.fgt_ipaddress_a["4"]
    ha_netmask            = var.ha_netmask
    untrusted_gateway_ip  = local.untrusted_gateway_ip
    trusted_gateway_ip    = local.trusted_gateway_ip
    management_gateway_ip = local.management_gateway_ip
    priority              = 100
    fgt_password          = var.fgt_password
    vcn_cidr              = var.vcn
  })
}



