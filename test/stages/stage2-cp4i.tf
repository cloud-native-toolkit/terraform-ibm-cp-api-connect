module "cp4i" {
  source = "github.com/ibm-garage-cloud/terraform-ibm-cp-catalog"

  cluster_config_file = module.dev_cluster.config_file_path
  release_namespace   = module.dev_tools_namespace.name
  entitlement_key     = var.entitlement_key
}
