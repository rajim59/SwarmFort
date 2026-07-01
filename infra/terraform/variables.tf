variable "resource_group_name" {
  type    = string
  default = "swarmfort-resources-v3"
}

variable "location" {
  type    = string
  default = "malaysiawest"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "manager_vm_size" {
  type    = string
  default = "Standard_B2ats_v2"
}

variable "worker_vm_size" {
  type    = string
  default = "Standard_B2ats_v2"
}

variable "allowed_ssh_ip" {
  type    = string
  default = "*"
}