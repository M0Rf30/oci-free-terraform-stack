# Remote state in OCI Object Storage (S3-compatible API).
#
# OCI is configured via the AWS S3 backend pointed at the region's S3-compat
# endpoint. Credentials are an OCI "Customer Secret Key" (an S3 access-key /
# secret-key pair), supplied via AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
#
# The endpoint namespace + region are baked in here; override at init time with
# `-backend-config=...` if you deploy to a different tenancy/region.
terraform {
  backend "s3" {
    bucket = "tf-state"
    key    = "oci-stack/terraform.tfstate"
    region = "eu-milan-1"

    endpoints = {
      s3 = "https://axwsje9nvbo1.compat.objectstorage.eu-milan-1.oraclecloud.com"
    }

    # OCI's S3-compat layer is not real AWS — skip all AWS-isms.
    use_path_style              = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
