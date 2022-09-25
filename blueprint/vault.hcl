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
  depends_on = ["template.vault-policy-kong", "template.vault-policy-api"]
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
  source = <<EOF
path "kuma/creds/kong-role" {
  capabilities = ["read"]
}
EOF
destination = "${data("vault_config/policies")}/kong.hcl"
}

template "vault-policy-api" {
  source = <<EOF
path "kuma/creds/api-role" {
  capabilities = ["read"]
}
EOF
destination = "${data("vault_config/policies")}/api.hcl"
}

template "vault-policy-database" {
  source = <<EOF
path "kuma/creds/database-role" {
  capabilities = ["read"]
}
EOF
destination = "${data("vault_config/policies")}/database.hcl"
}

template "vault-policy-kuma-admins" {
  source = <<EOF
path "kuma/creds/kuma-admin-role" {
  capabilities = ["read"]
}
EOF
destination = "${data("vault_config/policies")}/kuma_admin.hcl"
}

exec_remote "vault_kuma_plugin_configure" {
    depends_on = ["module.kuma_cp", "module.vault", "template.vault-config-script"]

    image {
        name = "hashicorp/vault:1.11.3"
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

    volume {
        source      = data("/approles/api")
        destination = "/config/api/approle"
    }

    volume {
        source      = data("/approles/database")
        destination = "/config/database/approle"
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