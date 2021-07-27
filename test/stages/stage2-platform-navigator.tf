module "platform-navigator" {
  source = "github.com/ibm-garage-cloud/terraform-ibm-cp-platform-navigator"

  catalog_name        = module.cp4i.name
  cluster_type        = module.dev_cluster.type_code
  cluster_config_file = module.dev_cluster.config_file_path
  namespace           = module.dev_tools_namespace.name
}
