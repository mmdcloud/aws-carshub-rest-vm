# -----------------------------------------------------------------------------------------
# Signing Profile & Destination Bucket
# -----------------------------------------------------------------------------------------
module "carshub_media_update_function_code_signed" {
  source             = "../../../modules/s3"
  bucket_name        = "carshub-media-update-function-code-signed${var.env}-${var.region}"
  versioning_enabled = "Enabled"
  force_destroy      = false
  bucket_policy      = ""
  cors               = []
  tags = {
    Name        = "carshub-media-update-function-code-signed${var.env}-${var.region}"
    Environment = var.env
    Project     = var.project
  }
}

module "carshub_signing_profile" {
  source                           = "../../../modules/signing-profile"
  platform_id                      = "AWSLambda-SHA384-ECDSA"
  signature_validity_value         = 5
  signature_validity_type          = "YEARS"
  ignore_signing_job_failure       = false
  untrusted_artifact_on_deployment = "Warn"
  s3_bucket_key                    = "lambda.zip"
  s3_bucket_source                 = module.carshub_media_update_function_code.bucket
  s3_bucket_version                = module.carshub_media_update_function_code.objects[0].version_id
  s3_bucket_destination            = module.carshub_media_update_function_code_signed.bucket
}
