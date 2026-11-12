##############################################################################################################
#
# DRGv2 Hub and Spoke traffic inspection
# FortiGate Active/Active Load Balanced pair of standalone FortiGate VMs for resilience and scale
# Terraform deployment template for Oracle Cloud
#
##############################################################################################################

# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Gets the boot volume attachments for each instance
data "oci_core_boot_volume_attachments" "block_attach_fgt_a" {
  depends_on          = [oci_core_instance.vm_fgt_a]
  availability_domain = oci_core_instance.vm_fgt_a.availability_domain
  compartment_id      = var.compartment_ocid
  instance_id         = oci_core_instance.vm_fgt_a.id
}

# Gets the boot volume attachments for each instance
data "oci_core_boot_volume_attachments" "block_attach_fgt_b" {
  depends_on          = [oci_core_instance.vm_fgt_b]
  availability_domain = oci_core_instance.vm_fgt_b.availability_domain
  compartment_id      = var.compartment_ocid
  instance_id         = oci_core_instance.vm_fgt_b.id
}

data "oci_core_private_ips" "fw_private_ip" {
  vnic_id   = element(oci_core_vnic_attachment.vnic_attach_trusted_fgt_a.*.vnic_id, 0)
  subnet_id = local.trusted_subnet_id
}

##############################################################################################################
# Existing subnet lookups + network selectors (used when create_network = false)
##############################################################################################################

data "oci_core_subnet" "untrusted_existing" {
  count     = var.create_network ? 0 : 1
  subnet_id = var.existing_untrusted_subnet_id
}

data "oci_core_subnet" "trusted_existing" {
  count     = var.create_network ? 0 : 1
  subnet_id = var.existing_trusted_subnet_id
}

data "oci_core_subnet" "hbdev_existing" {
  count     = var.create_network ? 0 : 1
  subnet_id = var.existing_hbdev_subnet_id
}

data "oci_core_subnet" "management_existing" {
  count     = var.create_network ? 0 : 1
  subnet_id = var.existing_management_subnet_id
}

locals {
  untrusted_subnet_id  = var.create_network ? oci_core_subnet.untrusted_subnet[0].id : var.existing_untrusted_subnet_id
  trusted_subnet_id    = var.create_network ? oci_core_subnet.trusted_subnet[0].id : var.existing_trusted_subnet_id
  hbdev_subnet_id      = var.create_network ? oci_core_subnet.hbdev_subnet[0].id : var.existing_hbdev_subnet_id
  management_subnet_id = var.create_network ? oci_core_subnet.management_subnet[0].id : var.existing_management_subnet_id

  untrusted_gateway_ip  = var.create_network ? oci_core_subnet.untrusted_subnet[0].virtual_router_ip : data.oci_core_subnet.untrusted_existing[0].virtual_router_ip
  trusted_gateway_ip    = var.create_network ? oci_core_subnet.trusted_subnet[0].virtual_router_ip : data.oci_core_subnet.trusted_existing[0].virtual_router_ip
  management_gateway_ip = var.create_network ? oci_core_subnet.management_subnet[0].virtual_router_ip : data.oci_core_subnet.management_existing[0].virtual_router_ip
}


