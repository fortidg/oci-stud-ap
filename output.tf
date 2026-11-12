##############################################################################################################
#
# DRGv2 Hub and Spoke traffic inspection
# FortiGate Active/Active Load Balanced pair of standalone FortiGate VMs for resilience and scale
# Terraform deployment template for Oracle Cloud
#
##############################################################################################################

//  Default Username and Password
output "Default_Username" {
  value = "admin"
}

output "Password" {
  value = var.fgt_password
}

// FortiGate A
output "FGTAMGMTPublicIP" {
  value = oci_core_instance.vm_fgt_a.*.public_ip
}

// FortiGate B
output "FGTBMGMTPublicIP" {
  value = oci_core_instance.vm_fgt_b.*.public_ip
}

// External NLB Public IP
output "Untrusted_Float_Public_IP" {
  value = oci_core_public_ip.untrusted_float_public_ip.ip_address
}

// Trusted float IP - point your trusted subnet's default route here when
// bringing your own network (create_network = false).
output "Trusted_Float_Private_IP" {
  value = oci_core_private_ip.trusted_float_fgt_a.ip_address
}

output "Trusted_Float_Private_IP_OCID" {
  value = oci_core_private_ip.trusted_float_fgt_a.id
}

// Marketplace image resolved for the FortiGate instances
output "MP_Listing_ID" {
  value = local.mp_listing_id
}

output "MP_Listing_Resource_ID" {
  value = local.mp_listing_resource_id
}

output "MP_Listing_Resource_Version" {
  value = local.mp_listing_resource_version
}
