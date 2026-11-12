##############################################################################################################
#
# Freeform tags applied to every taggable resource in this template.
#
# These are a cleanup backstop: if a student's Resource Manager stack (and its
# state) is lost or a destroy job fails part way, leftover resources can still
# be found with OCI Search, e.g.
#
#   oci search resource structured-search --query-text \
#     "query all resources where (freeformTags.key = 'class' && freeformTags.value = 'oci-ap-lab')"
#
##############################################################################################################

variable "class_name" {
  description = "Class or event identifier, applied as the 'class' tag on every resource."
  type        = string
  default     = "oci-ap-lab"
}

variable "student_name" {
  description = "Optional student identifier, applied as the 'student' tag on every resource. Omitted when empty."
  type        = string
  default     = ""
}

locals {
  freeform_tags = merge(
    {
      "class"      = var.class_name
      "managed-by" = "terraform"
    },
    var.student_name != "" ? { "student" = var.student_name } : {}
  )
}
