/*
template "backend-bootstrap" {
    source = <<EOF
#!/bin/bash -x

curl -O -L https://releases.hashicorp.com/vault/1.11.3/vault_1.11.3_linux_arm64.zip
unzip vault_1.11.3_linux_arm64.zip
mv vault /usr/local/bin

curl -O -L https://download.konghq.com/mesh-alpine/kuma-1.8.0-debian-arm64.tar.gz
tar xvzf kuma-1.8.0-debian-arm64.tar.gz
mv /kuma-1.8.0/bin/* /usr/local/bin

export VAULT_TOKEN=$(vault write auth/approle/login role_id=@/backend/approle/roleid secret_id=@/backend/approle/secretid -format=json | jq -r .auth.client_token)
vault read kuma/creds/backend-role -format=json | jq -r .data.token > /backend/kuma-token-backend

kuma-dp run --cp-address=https://kuma-cp.container.shipyard.run:5678 \
    --dataplane-file=/config/backend-dp.yml \
    --dataplane-var address=`hostname -I | awk '{print $1}'` \
    --dataplane-token=$(cat /backend/kuma-token-backend) \
    --ca-cert-file=/kuma/config/kuma_cp_ca.cert

EOF

destination = "${data("kuma_config/scripts")}/join-dataplane-backend.sh"
}
*/
container "database" {
    depends_on = ["module.kuma_cp"]

    network {
        name = "network.local"
    }

    image {
        name = "gregoryhunt/kuma-dp-vault:v0.1.0"
    }

    volume {
        source      = "./configs/database"
        destination = "/config"
    }

    volume {
        source      = data("kuma_config")
        destination = "/kuma/config"
    }

    volume {
        source      = data("/approles/database")
        destination = "/etc/vault/approle"
    }

    volume {
        source      = data("vault/agent/database")
        destination = "/etc/vault"
    }
    env {
        key   = "VAULT_ADDR"
        value = "http://vault.container.shipyard.run:8200"
    }

    env {
        key = "LISTEN_ADDR:127.0.0.1:9091"
        value = "off"
    }
    env {
        key = "NAME"
        value = "Database"
    }

    port {
        local = 9091
        remote = 9091
        host = 9091       
    }         
}

template "database-vault-agent-config" {
    source = <<EOF
exit_after_auth = true
pid_file = "./pidfile"

auto_auth {
    method {
        type = "approle"

        config = {
            role_id_file_path = "/etc/vault/approle/roleid"
            secret_id_file_path = "/etc/vault/approle/secretid"
        }
    }
    template {
        contents     = "{{ with secret \"kuma/creds/database-role\" }}{{ .Data.token }}{{ end }}"
        destination  = "/etc/vault/kuma-dataplane-token"
    }
}    

EOF

    destination = "${data("vault/agent/database")}/agent-config.hcl"
}