variable "queue_name" {}
variable "delay_seconds" {}
variable "max_message_size" {}
variable "message_retention_seconds" {}
variable "visibility_timeout_seconds" {}
variable "receive_wait_time_seconds" {}
variable "maxReceiveCount" {
  default = null
}
variable "dead_letter_target_arn" {
  default = null
}
variable "policy" {
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}
