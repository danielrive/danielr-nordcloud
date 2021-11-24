variable "NAME" {
  type = any
}

variable "ENV" {
  type = any
}

variable "CIDR" {
  type = any
}

variable "AZS" {
  type = any
}

variable "PRIVATE_SUBNETS" {
  type = any
}

variable "PUBLIC_SUBNETS" {
  type = any
}

variable "DATABASE_SUBNETS" {
  type = any
}

variable "CREATE_DATABASE_SUBNET_GROUP" {
  type    = any
  default = true
}

variable "CREATE_DATABASE_NAT_GATEWAY_ROUTE" {
  type    = any
  default = false
}

variable "CREATE_DATABASE_INTERNET_GATEWAY_ROUTE" {
  type    = any
  default = false
}

variable "ENABLE_NAT_GATEWAY" {
  type    = any
  default = true
}

variable "SINGLE_NAT_GATEWAY" {
  type    = any
  default = false
}

variable "ONE_NAT_GATEWAY_PER_AZ" {
  type    = any
  default = true
}

variable "TAGS" {
  type    = any
  default = {}
}