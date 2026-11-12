data "oci_core_app_catalog_listings" "marketplace_listing" {
  count        = trimspace(var.mp_listing_id) == "" ? 1 : 0
  display_name = var.mp_listing_display_name
}

data "oci_core_app_catalog_listing_resource_version" "marketplace_listing_resource_version" {
  count            = trimspace(var.mp_listing_resource_id) == "" ? 1 : 0
  listing_id       = trimspace(var.mp_listing_id) != "" ? var.mp_listing_id : data.oci_core_app_catalog_listings.marketplace_listing[0].app_catalog_listings[0].listing_id
  resource_version = var.mp_listing_resource_version
}

// Local variables pointing to the Marketplace catalog resource.
locals {
  mp_listing_id = trimspace(var.mp_listing_id) != "" ? var.mp_listing_id : data.oci_core_app_catalog_listings.marketplace_listing[0].app_catalog_listings[0].listing_id
  mp_listing_resource_id = trimspace(var.mp_listing_resource_id) != "" ? var.mp_listing_resource_id : data.oci_core_app_catalog_listing_resource_version.marketplace_listing_resource_version[0].listing_resource_id
  mp_listing_resource_version = var.mp_listing_resource_version
}

//Get Image Agreement
resource "oci_core_app_catalog_listing_resource_version_agreement" "mp_image_agreement" {
  listing_id               = local.mp_listing_id
  listing_resource_version = local.mp_listing_resource_version
}

//Accept Terms and Subscribe to the image, placing the image in a particular compartment
resource "oci_core_app_catalog_subscription" "mp_image_subscription" {
  compartment_id           = var.compartment_ocid
  eula_link                = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.eula_link
  listing_id               = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.listing_id
  listing_resource_version = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.listing_resource_version
  oracle_terms_of_use_link = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.oracle_terms_of_use_link
  signature                = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.signature
  time_retrieved           = oci_core_app_catalog_listing_resource_version_agreement.mp_image_agreement.time_retrieved

  timeouts {
    create = "30m"
  }
}

