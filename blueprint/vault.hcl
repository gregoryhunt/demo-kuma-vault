
variable "vault_network" {
  default = "local"
}

variable "vault_bootstrap_script" {
  default = <<-EOF
  #/bin/sh -e
  vault status

  EOF
}

variable "vault_plugin_folder" {
  default     = "${file_dir()}/plugins"
  description = "Folder where vault will load custom plugins"
}

template "download_plugins" {
  source = <<-EOF
    #!/bin/sh

    ARCH=$(uname -m)
    if [ "$${ARCH}" == "x86_64" ]; then
      ARCH="amd64"
    else
      ARCH="arm64"
    fi

    if [ -f "/plugins/vault-plugin-kuma" ]; then
      return
    fi

    curl -s -L https://github.com/gregoryhunt/vault-plugin-kuma/releases/download/v0.0.2/vault-plugin-kuma-linux-$${ARCH}-0.0.2.zip -o /plugins/plugin.zip
    cd /plugins && unzip ./plugin.zip
    mv /plugins/artifacts/vault-plugin-kuma-linux-$${ARCH} /plugins/vault-plugin-kuma
    rm -rf /plugins/artifacts
    rm -rf /plugins/plugin.zip
    chmod +x /plugins/vault-plugin-kuma
  EOF

  destination = "${data("vault_config/scripts")}/download-plugins.sh"
}

exec_remote "download_plugins" {
    image {
        name = "alpine/curl:3.14"
    }

    cmd = "sh"
    args = [
      "/config/scripts/download-plugins.sh"
    ]

    volume {
      source      = data("/vault_config")
      destination = "/config"
    }
    
    volume {
      source      = var.vault_plugin_folder
      destination = "/plugins"
    }
}

module "vault" {
  depends_on = ["exec_remote.download_plugins"]
  source = "github.com/shipyard-run/blueprints?ref=144a4b75e44a8471d1f9b30d6f8a30c8d9e05e7e/modules//vault-dev"
}

template "vault-config-script" {
  depends_on = ["template.vault-policy-kong", "template.vault-policy-api", "exec_remote.download_plugins"]

  source = <<-EOF
  #!/bin/bash -x
  # Kuma Plugin Config
  
  vault secrets enable -path=kuma vault-plugin-kuma
  
  vault write kuma/config url=$KUMA_URL token=@$KUMA_TOKEN
  
  vault write kuma/roles/kong-role \
    token_name=kong \
    mesh=default \
    ttl=1h \
    max_ttl=24h \
    tags="kuma.io/service=kong"
  
  vault write kuma/roles/api-role \
    token_name=api \
    mesh=default \
    ttl=1h \
    max_ttl=24h \
    tags="kuma.io/service=api"
  
  vault write kuma/roles/database-role \
    token_name=database \
    mesh=default \
    ttl=1h \
    max_ttl=24h \
    tags="kuma.io/service=database"
  
  vault write kuma/roles/kuma-admin-role \
    token_name=jerry \
    mesh=default \
    ttl=1h \
    max_ttl=24h \
    groups="mesh-system:admin"
  
  # App Role Config
  
  vault auth enable approle
  
  vault write auth/approle/role/kong-role \
    token_ttl=30m \
    token_max_ttl=60m \
    token_policies=default,kong \
    bind_secret_id=true
  
  vault policy write kong /config/vault/polices/kong.hcl
  
  vault read auth/approle/role/kong-role/role-id -format=json | jq -r .data.role_id >> /config/kong/approle/roleid
  
  vault write -f auth/approle/role/kong-role/secret-id -format=json | jq -r .data.secret_id >> /config/kong/approle/secretid
  
  vault write auth/approle/role/api-role \
    token_ttl=30m \
    token_max_ttl=60m \
    token_policies=default,api \
    bind_secret_id=true
  
  vault policy write api /config/vault/polices/api.hcl
  
  vault read auth/approle/role/api-role/role-id -format=json | jq -r .data.role_id >> /config/api/approle/roleid
  
  vault write -f auth/approle/role/api-role/secret-id -format=json | jq -r .data.secret_id >> /config/api/approle/secretid
  
  vault write auth/approle/role/database-role \
    token_ttl=30m \
    token_max_ttl=60m \
    token_policies=default,database \
    bind_secret_id=true
  
  vault policy write database /config/vault/polices/database.hcl
  
  vault read auth/approle/role/database-role/role-id -format=json | jq -r .data.role_id >> /config/database/approle/roleid
  
  vault write -f auth/approle/role/database-role/secret-id -format=json | jq -r .data.secret_id >> /config/database/approle/secretid
 
  # Generate the user and pass for the Payments service, this is used by the guide, policy and other elements are created
  # by the end user
  vault write auth/approle/role/payments-role \
    token_ttl=30m \
    token_max_ttl=60m \
    token_policies=default,payments \
    bind_secret_id=true
  
  vault read auth/approle/role/payments-role/role-id -format=json | jq -r .data.role_id >> /config/payments/approle/roleid
  
  vault write -f auth/approle/role/payments-role/secret-id -format=json | jq -r .data.secret_id >> /config/payments/approle/secretid
  
  # App Role Config
  
  vault auth enable userpass
  
  vault write auth/userpass/users/jerry \
    password=secret123 \
    policies=kuma-admins
  
  vault policy write kuma-admins /config/vault/polices/kuma_admin.hcl
  
  EOF

  destination = "${data("vault_config/scripts")}/config-kuma-vault.sh"
}

template "vault-policy-kong" {
  source = <<-EOF
  path "kuma/creds/kong-role" {
    capabilities = ["read"]
  }
  EOF

  destination = "${data("vault_config/policies")}/kong.hcl"
}

template "vault-policy-api" {
  source = <<-EOF
  path "kuma/creds/api-role" {
    capabilities = ["read"]
  }
  EOF

  destination = "${data("vault_config/policies")}/api.hcl"
}

template "vault-policy-database" {
  source = <<-EOF
  path "kuma/creds/database-role" {
    capabilities = ["read"]
  }
  EOF

  destination = "${data("vault_config/policies")}/database.hcl"
}

template "vault-policy-kuma-admins" {
  source = <<-EOF
  path "kuma/creds/kuma-admin-role" {
    capabilities = ["read"]
  }
  EOF

  destination = "${data("vault_config/policies")}/kuma_admin.hcl"
}

container "vault_client" {
    depends_on = ["module.kuma_cp", "module.vault", "template.vault-config-script"]

    image {
      name = "shipyardrun/hashicorp-tools:v0.10.0"
    }

    command = [
        "tail", "-f", "/dev/null"
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

    volume {
        source      = data("/approles/api")
        destination = "/config/api/approle"
    }

    volume {
        source      = data("/approles/database")
        destination = "/config/database/approle"
    }
    
    volume {
        source      = data("/approles/payments")
        destination = "/config/payments/approle"
    }
    
    volume {
        source      = "./plugins"
        destination = "/plugins"
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

exec_remote "vault_kuma_plugin_configure" {
    depends_on = ["module.kuma_cp", "module.vault", "template.vault-config-script"]
    
    target = "container.vault_client"

    cmd = "sh"
    args = [
        "/config/vault/scripts/config-kuma-vault.sh"
    ]
}
