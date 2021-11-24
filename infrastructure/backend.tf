terraform {
  backend "remote" {
    organization = "danielrive"

    workspaces {
      name = "nordcloud-danielr"
    }
  }
}