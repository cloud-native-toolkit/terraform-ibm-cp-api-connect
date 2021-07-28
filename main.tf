locals {
  tmp_dir           = "${path.cwd}/.tmp"
  gitops_global     = var.gitops_dir != "" ? var.gitops_dir : "${path.cwd}/gitops"
  gitops_dir        = "${local.gitops_global}/app-connect"
  instance_dir      = "${local.gitops_dir}/instances"

  storage_class_file = "${local.tmp_dir}/default_storage_class.out"
  default_storage_class = data.local_file.default_storage_class.content
  storage_class     = var.storage_class != "" ? var.storage_class : local.default_storage_class

  operatorgroup_name = "ibm-apiconnect"
  subscription_name = "ibm-apiconnect"
  subscription_namespace = "openshift-operators"

  license = {
    accept = true
    license = "L-APEH-BSVCHU"
    use = "CloudPakForIntegrationNonProduction"
  }

  operatorgroup = {
    file     = "${local.gitops_dir}/subscription.yaml"
    instance = {
      apiVersion = "operators.coreos.com/v1alpha1"
      kind = "OperatorGroup"
      metadata = {
        name = local.operatorgroup_name
        namespace = local.subscription_namespace
      }
      spec = {
        targetNamespaces = [local.subscription_namespace]
      }
    }
  }

  subscription = {
    file     = "${local.gitops_dir}/subscription.yaml"
    instance = {
      apiVersion = "operators.coreos.com/v1alpha1"
      kind = "Subscription"
      metadata = {
        name = local.subscription_name
        namespace = local.subscription_namespace
      }
      spec = {
        channel = "v2.1-eus"
        installPlanApproval = "Automatic"
        name = "ibm-apiconnect"
        source = var.catalog_name
        sourceNamespace = "openshift-marketplace"
      }
    }
  }

  integration-server = {
    file = "${local.instance_dir}/integration-server.yaml"
    instance = {
      apiVersion = "apiconnect.ibm.com/v1beta1"
      kind = "IntegrationServer"
      metadata = {
        name = "is-01-toolkit"
      }
      spec = {
        license = local.license
        pod = {
          containers = {
            runtime = {
              resources = {
                limits = {
                  cpu = "300m"
                  memory = "300Mi"
                }
                requests = {
                  cpu = "300m"
                  memory = "300Mi"
                }
              }
            }
          }
        }
        adminServerSecure = true
        router = {
          timeout = "120s"
        }
        useCommonServices = true
        designerFlowsOperationMode = "disabled"
        service = {
          endpointType = "http"
        }
        version = "11.0.0"
        replicas = 1
      }
    }
  }
  switch-server = {
    file = "${local.instance_dir}/switch-server.yaml"
    instance = {
      apiVersion = "apiconnect.ibm.com/v1beta1"
      kind = "SwitchServer"
      metadata = {
        name = "ss-01-quickstart"
      }
      spec = {
        license = local.license
        useCommonServices = true
        version = "11.0.0"
      }
    }
  }
  designer = {
    file = "${local.instance_dir}/designer.yaml"
    instance = {
      apiVersion = "apiconnect.ibm.com/v1beta1"
      kind = "DesignerAuthoring"
      metadata = {
        name = "des-01-quickstart"
      }
      spec = {
        couchdb = {
          replicas = 1
          storage = {
            class = local.storage_class
            size = "10Gi"
            type = "persistent-claim"
          }
        }
        designerFlowsOperationMode = "local"
        license = local.license
        replicas = 1
        useCommonServices = true
        version = "11.0.0"
      }
    }
  }
  dashboard = {
    file = "${local.instance_dir}/dashboard.yaml"
    instance = {
      apiVersion = "apiconnect.ibm.com/v1beta1"
      kind = "Dashboard"
      metadata = {
        name = "db-01-quickstart"
      }
      spec = {
        license = local.license
        pod = {
          containers = {
            content-server = {
              resources = {
                limits = {
                  cpu = "250m"
                }
              }
            }
            control-ui = {
              resources = {
                limits = {
                  cpu = "250m"
                  memory = "250Mi"
                }
              }
            }
          }
        }
        replicas = 1
        storage = {
          class = local.storage_class
          size = "5Gi"
          type = "persistent-claim"
        }
        useCommonServices = true
        version = "11.0.0"
      }
    }
  }

  base_instances = [
    local.integration-server,
    local.switch-server,
    local.designer
  ]
  instance_config = []
  #concat(local.base_instances, var.dashboard ? [local.dashboard] : [])
}

resource null_resource create_dirs {
  provisioner "local-exec" {
    command = "mkdir -p ${local.tmp_dir}"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${local.instance_dir}"
  }

  provisioner "local-exec" {
    command = "echo ${var.platform-navigator-name}"
  }
}

resource null_resource default_storage_class {
  depends_on = [null_resource.create_dirs]

  provisioner "local-exec" {
    command = "${path.module}/scripts/get-default-storage-class.sh ${local.storage_class_file}"

    environment = {
      KUBECONFIG = var.cluster_config_file
    }
  }
}

data local_file default_storage_class {
  depends_on = [null_resource.default_storage_class]

  filename = local.storage_class_file
}

resource local_file operatorgroup_yaml {
  depends_on = [null_resource.create_dirs]

  filename = local.operatorgroup.file

  content = yamlencode(local.operatorgroup.instance)
}
resource null_resource create_operatorgroup {
  depends_on = [local_file.operatorgroup_yaml]

  triggers = {
    KUBECONFIG = var.cluster_config_file
    namespace = local.subscription_namespace
    name = local.operatorgroup_name
    file = local_file.subscription_yaml.filename
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${self.triggers.file}"

    environment = {
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "kubectl delete -f ${self.triggers.file}"

    environment = {
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }
}
resource local_file subscription_yaml {
  depends_on = [null_resource.create_dirs]

  filename = local.subscription.file

  content = yamlencode(local.subscription.instance)
}

resource null_resource create_subscription {
  depends_on = [local_file.subscription_yaml, null_resource.create_operatorgroup]

  triggers = {
    KUBECONFIG = var.cluster_config_file
    namespace = local.subscription_namespace
    name = local.subscription_name
    file = local_file.subscription_yaml.filename
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${self.triggers.file} && ${path.module}/scripts/wait-for-csv.sh ${self.triggers.namespace} ibm-integration-platform-navigator"

    environment = {
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "kubectl delete -f ${self.triggers.file}"

    environment = {
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }
}

resource local_file instance_yaml {
  depends_on = [null_resource.create_dirs]
  count = length(local.instance_config.*.file)

  filename = local.instance_config[count.index].file

  content = yamlencode(local.instance_config[count.index].instance)
}

resource null_resource create_instances {
  depends_on = [local_file.instance_yaml, null_resource.create_subscription]
  count = length(local.instance_config.*.file)

  triggers = {
    KUBECONFIG = var.cluster_config_file
    namespace = var.namespace
    dir = local.instance_dir
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-for-crds.sh && oc apply -n ${self.triggers.namespace} -f ${local_file.instance_yaml[count.index].filename}"

    environment = {
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "kubectl delete -n ${self.triggers.namespace} -f ${self.triggers.dir} --ignore-not-found=true"

    environment = {
      KUBECONFIG = self.triggers.KUBECONFIG
    }
  }
}
