variable "namespace" {}
variable "name" {}
variable "replicacount" {}
variable "node_name" {}
variable "storage_size" {
  default = "10Gi"
}
variable "pvc_name" {
  default = null
}
variable "request_cpu" {
  default = "250m"
}
variable "request_mem" {
  default = "1Gi"
}
variable "limit_cpu" {
  default = "1"
}
variable "limit_mem" {
  default = "2Gi"
}

