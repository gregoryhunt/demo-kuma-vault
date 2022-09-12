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

  EOF
}

template "vault-config-script" {
  depends_on = ["template.vault-policy-kong"]
  source = <<EOF
#!/bin/bash -x

# Add jq
apk add jq

# Kuma Plugin Config

vault secrets enable -path=kuma vault-plugin-kuma

vault write kuma/config url=$KUMA_URL token=@$KUMA_TOKEN

vault write kuma/roles/kong-role \
  token_name=kong \
  mesh=default \
  ttl=1h \
  max_ttl=24h \
  tags="kuma.io/service=kong"



# App Role Config

vault auth enable approle

vault write auth/approle/role/kong-role \
  token_ttl=30m \
  token_max_ttl=60m \
  token_policies=default,kong \
  bind_secret_id=true

vault policy write kong /config/vault/polices/kong.hcl

vault read auth/approle/role/kong-role/role-id -format=json | jq -r .data.role_id >> /config/kong/approle/kong-role.id

vault write -f auth/approle/role/kong-role/secret-id -format=json | jq -r .data.secret_id >> /config/kong/approle/kong-role.secret

EOF
destination = "${data("vault_config/scripts")}/config-kuma-vault.sh"
}

template "vault-policy-kong" {
  source = <<EOF
path "kuma/creds/kong-role" {
  capabilities = ["read"]
}
EOF
destination = "${data("vault_config/policies")}/kong.hcl"
}

exec_remote "vault_kuma_plugin_configure" {
    depends_on = ["module.kuma_cp", "module.vault", "template.vault-config-script"]

    image {
        name = "hashicorp/vault:1.10.3"
    }

    cmd = "sh"
    args = [
        "/config/vault/scripts/config-kuma-vault.sh"
    ]

    volume {
        source      = data("/kuma_config")
        destination = "/config/kuma"
    }

    volume {
        source      = data("/vault_config/policies")
        destination = "/config/vault/polices"
    }

    volume {
        source      = data("/vault_config/scripts")
        destination = "/config/vault/scripts"
    }

    volume {
        source      = data("/approles/kong")
        destination = "/config/kong/approle"
    }

    env {
        key   = "VAULT_ADDR"
        value = "http://vault.container.shipyard.run:8200"
    }
    env {
        key   = "VAULT_TOKEN"
        value = "root"
    }
    env {
        key   = "KUMA_URL"
        value = "http://kuma-cp.container.shipyard.run:5681"
    }
    env {
        key   = "KUMA_TOKEN"
        value = "/config/kuma/admin.token"
    }

    network {
        name = "network.local"
  }
}

/*
container "vault_kuma_plugin_configure" {
    depends_on = ["module.kuma_cp", "module.vault"]

    image {
        name = "hashicorp/vault:1.10.3"
    }

    entrypoint = [""]

    command = [
      "tail",
      "-f",
      "/dev/null"
    ]

    volume {
        source      = data("/kuma_config")
        destination = "/config/kuma"
    }

    volume {
        source      = data("/vault_config/policies")
        destination = "/config/vault/polices"
    }

    volume {
        source      = data("/vault_config/scripts")
        destination = "/config/vault/scripts"
    }

    volume {
        source      = data("/approles/kong")
        destination = "/config/kong/approle"
    }

    env {
        key   = "VAULT_ADDR"
        value = "http://vault.container.shipyard.run:8200"
    }
    env {
        key   = "VAULT_TOKEN"
        value = "root"
    }
    env {
        key   = "KUMA_URL"
        value = "http://kuma-cp.container.shipyard.run:5681"
    }
    env {
        key   = "KUMA_TOKEN"
        value = "/config/kuma/admin.token"
    }

    network {
        name = "network.local"
  }
}
*/