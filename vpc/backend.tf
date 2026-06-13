# This directory is consumed as a LOCAL child module (source = "./vpc") from the
# root configuration, so it does NOT declare its own backend — Terraform state
# is owned by the root module (see ../backend.tf). A `backend` block here would
# be ignored by Terraform.
#
# This file exists to match the required project structure. If you ever promote
# vpc/ to a standalone root configuration, put its
# `terraform { backend "s3" {} }` block here.