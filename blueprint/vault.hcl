module "vault" {
  source = "github.com/shipyard-run/blueprints?ref=144a4b75e44a8471d1f9b30d6f8a30c8d9e05e7e/modules//vault-dev"
}

variable "vault_network" {
  default = "local"
}

variable "vault_plugin_folder" {
  default     = "${file_dir()}/plugins"
  description = "Folder where vault will load custom plugins"
}

variable "vault_bootstrap_script" {
  default = <<-EOF
  #/bin/sh -e
  vault status
  vault auth enable approle
  vault secrets enable -path=kuma vault-plugin-kuma



  vault write auth/approle/role/kong-role \
    token_ttl=30m \
    token_max_ttl=60m \
    token_policies=default,kong
    bind_secret_id=true
  EOF
}

exec_remote "vault_kuma_plugin_configure" {
    depends_on = ["module.kuma_cp", "module.vault"]

    image {
        name = "hashicorp/vault:1.10.3"
    }

    cmd = "vault"
    args = [
        "write",
        "kuma/config",
        "url=http://kuma-cp.container.shipyard.run:5681",
        "token=@/config/admin.token"
    ]

    volume {
        source      = data("/kuma_config")
        destination = "/config"
    }

    env {
        key = "VAULT_ADDR"
        value = "http://vault.container.shipyard.run:8200"
    }
    env {
        key = "VAULT_TOKEN"
        value = "root"
    }
    env {
        key = "KUMA_URL"
        value = "http://kuma-cp.container.shipyard.run:5681"
    }
    env {
        key = "KUMA_TOKEN"
        value = "/config/admin.token"
    }

    network {
        name = "network.local"
  }
}