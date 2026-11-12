
## oci-ap

This Terraform deploy Active/Passive FortiGate in Security Services VCN with 5 subnets.

You may run into an issue where cloudinit fails to load the full FortiGate Configuration.  Usually, this happens on the vNICs attached to the instance after initial bootup.  You will need to ssh to the FortiGate and issue the ```exec factoryreset``` command.  This will cause the cloudinit to run again.  When the device comes up, it should be functioning properly:

This terraform can resolve the marketplace image dynamically from the listing display name and version. By default it looks up the current PAYGO FortiGate listing, so you usually only need to set `mp_listing_display_name` and `mp_listing_resource_version` if you want a different listing or version. If needed, you can still override the lookup by setting `mp_listing_id` and `mp_listing_resource_id` explicitly.

**Licensing.** The FortiGates use the PAYG (pay-as-you-go) Marketplace image, so no license file or token is needed. Licensing is billed through OCI.

## Deploying with OCI Resource Manager (students)

This template is designed to run as an OCI Resource Manager stack, so Terraform state is stored by OCI rather than on a student's laptop, and no API keys are needed.

1. Get the stack zip from your instructor (built with `scripts/package-stack.sh`).
2. In the OCI Console, open **Developer Services → Resource Manager → Stacks → Create stack**.
3. Choose **My configuration → .zip file**, upload the zip, and select **your assigned compartment** as the stack's compartment.
4. Pick the newest Terraform version offered (the template needs 1.3 or later).
5. On the variables page, fill in **Name prefix**, keep the **Class** value your instructor gave you, and set the FortiGate password.
6. Run **Apply**. Outputs (management IPs, password, float IPs) appear on the job's **Outputs** tab.

When you are finished, run **Destroy** on the stack. Your instructor can also destroy it for you.

## Instructor setup and cleanup

**Packaging.** `scripts/package-stack.sh` writes `dist/oci-ap-stack.zip` containing only the `.tf` files, `customdata.tpl` and `schema.yaml`. State, tfvars and plan files are never included. `schema.yaml` controls the stack's variable form: student-facing fields are shown, and the tenancy, region, API-key and network-layout variables are hidden.

**Permissions.** Each student needs to manage stacks, jobs and the deployed resources in their own compartment. Lab environments usually do this with one group per student, for example:

```
Allow group student01 to manage all-resources in compartment Students:student01
```

**Tags.** Every taggable resource gets the freeform tags `class`, `student` (defaults to the name prefix) and `managed-by = terraform` (see `tags.tf`). Set the `class_name` default in `tags.tf` (or tell students the value) before each class.

**Cleanup**, run with your own OCI CLI credentials (requires `jq`):

```sh
# 1. Destroy every student's stack. Dry run first, then for real.
scripts/destroy-stacks.sh --parent <students-parent-compartment-ocid>
scripts/destroy-stacks.sh --parent <students-parent-compartment-ocid> --yes --delete-stacks

# 2. Backstop: list anything still left, by tag or by compartment.
scripts/find-leftovers.sh --class oci-ap-lab
scripts/find-leftovers.sh --compartment <student-compartment-ocid>
```

`destroy-stacks.sh` also accepts individual compartment OCIDs instead of `--parent`. Searching by compartment catches resources students created by hand, which won't carry the tags. OCI Search can take a few minutes to reflect recent deletes.

## Bring your own network (existing VCN/subnets)

By default this template creates the VCN, internet gateway, all subnets, route tables and security lists. If you have already provisioned a network, you can reuse it instead by setting `create_network = false` and selecting the existing VCN and subnets in the **Existing network (advanced)** section of the stack form. The equivalent variable values are:

```hcl
create_network                = false
existing_vcn_id               = "<vcn ocid>"
existing_untrusted_subnet_id  = "<untrusted subnet ocid>"
existing_trusted_subnet_id    = "<trusted subnet ocid>"
existing_hbdev_subnet_id      = "<heartbeat subnet ocid>"
existing_management_subnet_id = "<management subnet ocid>"
```

When `create_network = true` (the default), the existing-network variables are ignored and the network is built as before.

Notes when reusing an existing network:

- The FortiGate gateway IPs used during bootstrap are resolved automatically from the supplied subnets (their `virtual_router_ip`), so no extra input is required.
- **The FortiGate IP variables must fall inside your existing subnets' CIDRs.** The `fgt_ipaddress_a`, `fgt_ipaddress_b`, `unt_float_ipaddress`, `tr_float_ipaddress`, `trusted_nlb_ipaddress` and `subnetmask` values still default to the built-in `172.16.140.0/22` layout. These are hidden in the stack form, so if your existing subnets use different ranges, change their defaults in `variables.tf` to match, otherwise OCI rejects the VNIC with `IP Address is invalid: not in CIDR`.
- The trusted subnet's route table is **not** managed by this template in this mode. You must configure your trusted subnet to route `0.0.0.0/0` to the FortiGate trusted float IP. After `terraform apply`, use the `Trusted_Float_Private_IP` (or `Trusted_Float_Private_IP_OCID`) output to create that route rule.

![diagram](images/a-p.png)