variable "name_prefix" {
  type    = string
  default = "api"
}

variable "title" {
  type = string
}

variable "resource_policy_allow_read_cloudfront_distribution_arns" {
  type    = list(string)
  default = null
}

variable "apis" {
  type = map(object({
    name          = string
    open_api_spec = string
  }))
}

variable "tags" {
  type = map(string)
}
