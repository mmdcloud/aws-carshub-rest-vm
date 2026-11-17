output "config_arn" {
  value = aws_lambda_code_signing_config.signing_config.arn
}

output "job_id" {
  value = aws_signer_signing_job.build_signing_job.job_id
}

output "signed_object_key" {
  value = "${aws_signer_signing_job.build_signing_job.job_id}.zip"
}

output "destination_bucket" {
  value = var.s3_bucket_destination
}
