terraform {
  required_version = "~> 1.14"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}
