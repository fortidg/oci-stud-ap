##############################################################################################################
#
# DRGv2 Hub and Spoke traffic inspection
# FortiGate Active/Active Load Balanced pair of standalone FortiGate VMs for resilience and scale
# Terraform deployment template for Oracle Cloud
#
##############################################################################################################

// In OCI Resource Manager, authentication is handled by the service and
// user_ocid / fingerprint / private_key_path are left empty (null).
// When running Terraform locally, set them in terraform.tfvars.
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  region           = var.region
  user_ocid        = var.user_ocid == "" ? null : var.user_ocid
  fingerprint      = var.fingerprint == "" ? null : var.fingerprint
  private_key_path = var.private_key_path == "" ? null : var.private_key_path
}

terraform {
  required_version = ">=1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">=6.3.0"
    }
  }
}

