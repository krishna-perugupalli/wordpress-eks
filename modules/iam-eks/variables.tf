variable "name" { type = string } # cluster name
variable "tags" {
  type    = map(string)
  default = {}
}

# Optional extra policies you might want to attach to the node role
variable "extra_node_policy_arns" {
  type    = list(string)
  default = []
}

# Optional extra policies for cluster role (rarely needed)
variable "extra_cluster_policy_arns" {
  type    = list(string)
  default = []
}
