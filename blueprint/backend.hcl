template "backend-bootstrap" {
    source = <<EOF
#!/bin/bash -x

curl -O -L https://releases.hashicorp.com/vault/1.11.3/vault_1.11.3_linux_arm64.zip
unzip vault_1.11.3_linux_arm64.zip
mv vault /usr/local/bin

curl -O -L https://download.konghq.com/mesh-alpine/kuma-1.8.0-debian-arm64.tar.gz
tar xvzf kuma-1.8.0-debian-arm64.tar.gz
mv /kuma-1.8.0/bin/* /usr/local/bin

export VAULT_TOKEN=$(vault write auth/approle/login role_id=@/backend/approle/role-id secret_id=@/backend/approle/role-secret-id -format=json | jq -r .auth.client_token)
vault read kuma/creds/backend-role -format=json | jq -r .data.token > /backend/kuma-token-backend

kuma-dp run --cp-address=https://kuma-cp.container.shipyard.run:5678 \
    --dataplane-file=/config/backend-dp.yml \
    --dataplane-var address=`hostname -I | awk '{print $1}'` \
    --dataplane-token=$(cat /backend/kuma-token-backend) \
    --ca-cert-file=/kuma/config/kuma_cp_ca.cert

EOF

destination = "${data("kuma_config/scripts")}/join-dataplane-backend.sh"
}

container "backend" {
    depends_on = ["module.kuma_cp", "template.backend-bootstrap"]

    network {
        name = "network.local"
    }

    image {
        name = "nicholasjackson/fake-service:v0.24.2"
    }

    env {
        key = "LISTEN_ADDR:0.0.0.0:9090"
        value = "off"
    }
    env {
        key = "NAME"
        value = "Backend"
    }

    port {
        local = 9090
        remote = 9090
        host = 9090       
    }         
}

sidecar "backend-tools" {
    target = "container.backend"

    image {
        name = "shipyardrun/tools:v0.7.0"
    }

    //command = ["tail", "-f", "/dev/null"]
    command = ["sh", "/kuma/scripts/join-dataplane-backend.sh"]

    volume {
        source      = "./configs/backend"
        destination = "/config"
    }

    volume {
        source      = data("kuma_config")
        destination = "/kuma/config"
    }

    volume {
        source      = data("/approles/backend")
        destination = "/backend/approle"
    }

    volume {
        source      = data("kuma_config/scripts")
        destination = "/kuma/scripts"
    }    

    env {
        key   = "VAULT_ADDR"
        value = "http://vault.container.shipyard.run:8200"
    }

}