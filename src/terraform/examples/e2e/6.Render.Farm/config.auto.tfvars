resourceGroupName = "ArtistAnywhere.Farm" # Alphanumeric, underscores, hyphens, periods and parenthesis are allowed

activeDirectory = {
  enable           = true
  domainName       = "artist.studio"
  domainServerName = "WinScheduler"
  orgUnitPath      = ""
  adminUsername    = ""
  adminPassword    = ""
}

######################################################################################################
# Virtual Machine Scale Sets (https://learn.microsoft.com/azure/virtual-machine-scale-sets/overview) #
######################################################################################################

virtualMachineScaleSets = [
  {
    enable = false
    name   = "LnxFarmC"
    machine = {
      size  = "Standard_HB120rs_v3"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/2.0.0"
        plan = {
          enable    = false
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        sizeGB      = 0
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
      }
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
      sshPublicKey = "" # "ssh-rsa ..."
      passwordAuth = {
        disable = false
      }
    }
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.sh"
        parameters = {
          fileSystems = [
            {
              enable = false # File Storage
              mounts = [
                "URI_TO_AZURE_STORAGE_ACCOUNT:/azstudio1/content /mnt/content aznfs default,sec=sys,proto=tcp,vers=3,nolock 0 0"
              ]
            },
            {
              enable = false # File Cache
              mounts = [
                "cache.artist.studio:/content /mnt/content nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
              ]
            },
            {
              enable = true # Job Scheduler
              mounts = [
                "scheduler.artist.studio:/deadline /mnt/deadline nfs defaults 0 0"
              ]
            }
          ]
          terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
            enable       = true
            delayTimeout = "PT5M"
          }
        }
      }
      health = {
        enable      = true
        protocol    = "tcp"
        port        = 111
        requestPath = ""
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "LnxFarmG"
    machine = {
      size  = "Standard_NV36ads_A10_v5"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/2.1.0"
        plan = {
          enable    = false
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Linux"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        sizeGB      = 0
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
      }
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
      sshPublicKey = "" # "ssh-rsa ..."
      passwordAuth = {
        disable = false
      }
    }
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.sh"
        parameters = {
          fileSystems = [
            {
              enable = false # File Storage
              mounts = [
                "URI_TO_AZURE_STORAGE_ACCOUNT:/azstudio1/content /mnt/content aznfs default,sec=sys,proto=tcp,vers=3,nolock 0 0"
              ]
            },
            {
              enable = false # File Cache
              mounts = [
                "cache.artist.studio:/content /mnt/content nfs hard,proto=tcp,mountproto=tcp,retry=30,nolock 0 0"
              ]
            },
            {
              enable = true # Job Scheduler
              mounts = [
                "scheduler.artist.studio:/deadline /mnt/deadline nfs defaults 0 0"
              ]
            }
          ]
          terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
            enable       = true
            delayTimeout = "PT5M"
          }
        }
      }
      health = {
        enable      = true
        protocol    = "tcp"
        port        = 111
        requestPath = ""
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "WinFarmC"
    machine = {
      size  = "Standard_HB120rs_v3"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinFarm/versions/2.0.0"
        plan = {
          enable    = false
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        sizeGB      = 0
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
      }
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
      sshPublicKey = "" # "ssh-rsa ..."
      passwordAuth = {
        disable = false
      }
    }
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.ps1"
        parameters = {
          fileSystems = [
            {
              enable = false # File Storage
              mounts = [
                "mount -o anon nolock \\\\URI_TO_AZURE_STORAGE_ACCOUNT\\azstudio1\\content X:"
              ]
            },
            {
              enable = false # File Cache
              mounts = [
                "mount -o anon nolock \\\\cache.artist.studio\\content H:"
              ]
            },
            {
              enable = true # Job Scheduler
              mounts = [
                "mount -o anon \\\\scheduler.artist.studio\\deadline S:"
              ]
            }
          ]
          terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
            enable       = true
            delayTimeout = "PT5M"
          }
        }
      }
      health = {
        enable      = true
        protocol    = "tcp"
        port        = 445
        requestPath = ""
      }
      monitor = {
        enable = false
      }
    }
  },
  {
    enable = false
    name   = "WinFarmG"
    machine = {
      size  = "Standard_NV36ads_A10_v5"
      count = 2
      image = {
        id = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinFarm/versions/2.1.0"
        plan = {
          enable    = false
          publisher = ""
          product   = ""
          name      = ""
        }
      }
    }
    spot = {
      enable         = true     # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot
      evictionPolicy = "Delete" # https://learn.microsoft.com/azure/virtual-machine-scale-sets/use-spot#eviction-policy
    }
    network = {
      enableAcceleration = true
    }
    operatingSystem = {
      type = "Windows"
      disk = {
        storageType = "Standard_LRS"
        cachingType = "ReadOnly"
        sizeGB      = 0
        ephemeral = { # https://learn.microsoft.com/azure/virtual-machines/ephemeral-os-disks
          enable    = true
          placement = "ResourceDisk"
        }
      }
    }
    adminLogin = {
      userName     = ""
      userPassword = ""
      sshPublicKey = "" # "ssh-rsa ..."
      passwordAuth = {
        disable = false
      }
    }
    extension = {
      initialize = {
        enable   = true
        fileName = "initialize.ps1"
        parameters = {
          fileSystems = [
            {
              enable = false # File Storage
              mounts = [
                "mount -o anon nolock \\\\URI_TO_AZURE_STORAGE_ACCOUNT\\azstudio1\\content X:"
              ]
            },
            {
              enable = false # File Cache
              mounts = [
                "mount -o anon nolock \\\\cache.artist.studio\\content H:"
              ]
            },
            {
              enable = true # Job Scheduler
              mounts = [
                "mount -o anon \\\\scheduler.artist.studio\\deadline S:"
              ]
            }
          ]
          terminateNotification = { # https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-terminate-notification
            enable       = true
            delayTimeout = "PT5M"
          }
        }
      }
      health = {
        enable      = true
        protocol    = "tcp"
        port        = 445
        requestPath = ""
      }
      monitor = {
        enable = false
      }
    }
  }
]

############################################################################
# Batch (https://learn.microsoft.com/azure/batch/batch-technical-overview) #
############################################################################

batch = {
  enable = false
  account = {
    name = "azstudio"
    storage = {
      accountName       = ""
      resourceGroupName = ""
    }
  }
  pools = [
    {
      enable      = false
      name        = "LnxFarmC"
      displayName = "Linux Render Farm (CPU)"
      node = {
        image = {
          id      = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/2.0.0"
          agentId = "batch.node.el 9"
        }
        machine = {
          size  = "Standard_HB120rs_v3" # https://learn.microsoft.com/azure/batch/batch-pool-vm-sizes
          count = 2
        }
        osDisk = {
          ephemeral = {
            enable = false # https://learn.microsoft.com/azure/batch/create-pool-ephemeral-os-disk
          }
        }
        deallocationMode   = "TaskCompletion" # https://learn.microsoft.com/rest/api/batchservice/pool/remove-nodes
        maxConcurrentTasks = 1
      }
      fillMode = { # https://learn.microsoft.com/azure/batch/batch-parallel-node-tasks
        nodePack = {
          enable = true
        }
      }
      spot = { # https://learn.microsoft.com/azure/batch/batch-spot-vms
        enable = true
      }
    },
    {
      enable      = false
      name        = "LnxFarmG"
      displayName = "Linux Render Farm (GPU)"
      node = {
        image = {
          id      = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/Linux/versions/2.1.0"
          agentId = "batch.node.el 9"
        }
        machine = {
          size  = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/batch/batch-pool-vm-sizes
          count = 2
        }
        osDisk = {
          ephemeral = {
            enable = false # https://learn.microsoft.com/azure/batch/create-pool-ephemeral-os-disk
          }
        }
        deallocationMode   = "TaskCompletion" # https://learn.microsoft.com/rest/api/batchservice/pool/remove-nodes
        maxConcurrentTasks = 1
      }
      fillMode = { # https://learn.microsoft.com/azure/batch/batch-parallel-node-tasks
        nodePack = {
          enable = true
        }
      }
      spot = { # https://learn.microsoft.com/azure/batch/batch-spot-vms
        enable = true
      }
    },
    {
      enable      = false
      name        = "WinFarmC"
      displayName = "Windows Render Farm (CPU)"
      node = {
        image = {
          id      = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinFarm/versions/2.0.0"
          agentId = "batch.node.windows amd64"
        }
        machine = {
          size  = "Standard_HB120rs_v3" # https://learn.microsoft.com/azure/batch/batch-pool-vm-sizes
          count = 2
        }
        osDisk = {
          ephemeral = {
            enable = false # https://learn.microsoft.com/azure/batch/create-pool-ephemeral-os-disk
          }
        }
        deallocationMode   = "TaskCompletion" # https://learn.microsoft.com/rest/api/batchservice/pool/remove-nodes
        maxConcurrentTasks = 1
      }
      fillMode = { # https://learn.microsoft.com/azure/batch/batch-parallel-node-tasks
        nodePack = {
          enable = true
        }
      }
      spot = { # https://learn.microsoft.com/azure/batch/batch-spot-vms
        enable = true
      }
    },
    {
      enable      = false
      name        = "WinFarmG"
      displayName = "Windows Render Farm (GPU)"
      node = {
        image = {
          id      = "/subscriptions/5cc0d8f1-3643-410c-8646-1a2961134bd3/resourceGroups/ArtistAnywhere.Image/providers/Microsoft.Compute/galleries/azstudio/images/WinFarm/versions/2.1.0"
          agentId = "batch.node.windows amd64"
        }
        machine = {
          size  = "Standard_NV36ads_A10_v5" # https://learn.microsoft.com/azure/batch/batch-pool-vm-sizes
          count = 2
        }
        osDisk = {
          ephemeral = {
            enable = false # https://learn.microsoft.com/azure/batch/create-pool-ephemeral-os-disk
          }
        }
        deallocationMode   = "TaskCompletion" # https://learn.microsoft.com/rest/api/batchservice/pool/remove-nodes
        maxConcurrentTasks = 1
      }
      fillMode = { # https://learn.microsoft.com/azure/batch/batch-parallel-node-tasks
        nodePack = {
          enable = true
        }
      }
      spot = { # https://learn.microsoft.com/azure/batch/batch-spot-vms
        enable = true
      }
    }
  ]
}

################################################################################
# Azure OpenAI (https://learn.microsoft.com/azure/ai-services/openai/overview) #
################################################################################

azureOpenAI = {
  enable      = false
  regionName  = "EastUS"
  accountName = "azstudio"
  domainName  = ""
  serviceTier = "S0"
  chatDeployment = {
    model = {
      name    = "gpt-35-turbo"
      format  = "OpenAI"
      version = ""
      scale   = "Standard"
    }
    session = {
      context = ""
      request = ""
    }
  }
  imageGeneration = {
    description = ""
    height      = 1024
    width       = 1024
  }
  storage = {
    enable = false
  }
}

#####################################################
# https://learn.microsoft.com/azure/azure-functions #
#####################################################

functionApp = {
  enable = false
  name   = "azstudio"
  servicePlan = {
    computeTier = "S1"
    workerCount = 1
    alwaysOn    = true
  }
  monitor = {
    workspace = {
      sku = "PerGB2018"
    }
    insight = {
      type = "web"
    }
    retentionDays = 90
  }
}

#######################################################################
# Resource dependency configuration for pre-existing deployments only #
#######################################################################

existingNetwork = {
  enable            = false
  name              = ""
  subnetNameFarm    = ""
  subnetNameAI      = ""
  resourceGroupName = ""
}

existingStorage = {
  enable            = false
  name              = ""
  resourceGroupName = ""
  fileShareName     = ""
}
