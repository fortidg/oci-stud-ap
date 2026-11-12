##############################################################################################################
#
# DRGv2 Hub and Spoke traffic inspection
# FortiGate Active/Active Load Balanced pair of standalone FortiGate VMs for resilience and scale
# Terraform deployment template for Oracle Cloud
#
##############################################################################################################

variable "region" {
  description = "Oracle Cloud region"
  default     = "us-ashburn-1"
}

##############################################################################################################
# Oracle Cloud configuration
##############################################################################################################

variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "user_ocid" {
  default = ""
}
variable "private_key_path" {
  default = ""
}
variable "fingerprint" {
  default = ""
}




##############################################################################################################
# FortiGate instance type
##############################################################################################################
variable "instance_shape" {
  type    = string
  default = "VM.Standard3.Flex"
}

variable "instance_ocpus" {
  description = "OCPUs to use when instance_shape is an OCI Flex shape."
  type        = number
  default     = 4
}

variable "instance_memory_in_gbs" {
  description = "Memory in GB to use when instance_shape is an OCI Flex shape."
  type        = number
  default     = 60
}

variable "mp_listing_id" {
  description = "Optional override for the marketplace listing OCID. Leave blank to resolve it dynamically from mp_listing_display_name."
  default     = ""
}

variable "mp_listing_resource_id" {
  description = "Optional override for the marketplace image OCID. Leave blank to resolve it dynamically from the listing and version."
  default     = ""
}

variable "mp_listing_display_name" {
  description = "Marketplace listing name to resolve dynamically when mp_listing_id is not set."
  default     = "FortiGate Next-Gen Firewall (4 cores)"
}

// Version
variable "mp_listing_resource_version" {
  default = "7.6.8_(_X64_)"
}
// Cert use for SDN Connector setting
variable "cert" {
  type    = string
  default = "Fortinet_Factory"
}

##############################################################################################################
# VCN and SUBNET ADDRESSESS
##############################################################################################################

variable "vcn" {
  default = "172.16.140.0/22"
}

##############################################################################################################
# Existing network (bring your own VCN/subnets)
##############################################################################################################

# When true (default) this template creates the VCN, subnets, route tables and
# security lists. Set to false to reuse an existing network by supplying the
# OCIDs below. When false, the trusted subnet's route table must be configured
# (outside this template) to route 0.0.0.0/0 to the FortiGate trusted float IP.
variable "create_network" {
  type    = bool
  default = true
}

variable "existing_vcn_id" {
  description = "OCID of an existing VCN to use when create_network = false."
  type        = string
  default     = ""
}

variable "existing_untrusted_subnet_id" {
  description = "OCID of an existing untrusted subnet to use when create_network = false."
  type        = string
  default     = ""
}

variable "existing_trusted_subnet_id" {
  description = "OCID of an existing trusted subnet to use when create_network = false."
  type        = string
  default     = ""
}

variable "existing_hbdev_subnet_id" {
  description = "OCID of an existing heartbeat subnet to use when create_network = false."
  type        = string
  default     = ""
}

variable "existing_management_subnet_id" {
  description = "OCID of an existing management subnet to use when create_network = false."
  type        = string
  default     = ""
}

variable "subnet" {
  type        = map(string)
  description = ""

  default = {
    "1" = "172.16.140.0/28"   # Flexible Network Load Balancer
    "2" = "172.16.140.32/28"  # Untrusted
    "3" = "172.16.140.64/28"  # Trusted
    "4" = "172.16.140.96/28"  # Heartbeat
    "5" = "172.16.140.128/28" # Management
  }
}

variable "subnetmask" {
  type        = map(string)
  description = ""

  default = {
    "1" = "28" # Flexible Network Load Balancer
    "2" = "28" # Untrusted
    "3" = "28" # Trusted
    "4" = "28" # Heartbeat
    "5" = "28" # Management
  }
}

# variable "gateway" {
#   type        = map(string)
#   description = ""

#   default = {
#     "1" = "172.16.140.1"  # Flexible Network Load Balancer
#     "2" = "172.16.140.33" # Untrusted
#     "3" = "172.16.140.65" # Trusted
#     "4" = "172.16.140.97" # Heartbeat
#     "5" = "172.16.140.129" # Management
#   }
# }

variable "fgt_ipaddress_a" {
  type        = map(string)
  description = ""

  default = {
    "2" = "172.16.140.45"  # Untrusted
    "3" = "172.16.140.77"  # Trusted
    "4" = "172.16.140.109" # Heartbeat
    "5" = "172.16.140.141" # Management
  }
}

variable "fgt_ipaddress_b" {
  type        = map(string)
  description = ""

  default = {
    "2" = "172.16.140.46"  # Untrusted
    "3" = "172.16.140.78"  # Trusted
    "4" = "172.16.140.110" # Heartbeat
    "5" = "172.16.140.142" # Management
  }
}

variable "unt_float_ipaddress" {
  type        = map(string)
  description = ""

  default = {
    "2" = "172.16.140.34" # Untrusted
  }
}

variable "tr_float_ipaddress" {
  type        = map(string)
  description = ""

  default = {
    "3" = "172.16.140.66" # Trusted
  }
}


# Choose an Availability Domain (1,2,3)
variable "availability_domain" {
  type    = string
  default = "1"
}

variable "availability_domain2" {
  type    = string
  default = "2"
}

variable "volume_size" {
  type    = string
  default = "50" //GB; you can modify this, can't less than 50
}

variable "drg_attachment_network_details_vcn_route_type" {
  type    = string
  default = "VCN_CIDRS"
}

variable "ha_netmask" {
  type    = string
  default = "255.255.255.240"
}

variable "fgt_password" {
  type    = string
  default = "Fortinet1234!"
}
