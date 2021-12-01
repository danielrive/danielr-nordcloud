terraform {
  backend "remote" {
    organization = "danielrive"

    workspaces {
      name = "nordcloud-danielr"
    }
  }
}

#terraform {
#  backend "local" {
#    path = "./terraform.tfstate"
#  }
#}