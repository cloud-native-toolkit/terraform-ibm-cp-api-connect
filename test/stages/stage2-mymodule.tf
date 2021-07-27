module "dev_tools_mymodule" {
  source = "./module"

  catalog_name        = module.cp4i.name
  cluster_type        = module.dev_cluster.type_code
  cluster_config_file = module.dev_cluster.config_file_path
  namespace           = module.dev_tools_namespace.name
  platform-navigator-name = module.platform-navigator.name
  dashboard           = false
}
