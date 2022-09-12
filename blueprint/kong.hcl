container "kong" {
    depends_on = ["module.kuma_cp"]

    network {
        name = "network.local"
    }

    image {
        name = "kong:2.8.1-alpine"
    }

    volume {
        source      = "./configs/kong/"
        destination = "/kong/declarative/"
    }

    env {
        key = "KONG_DATABASE"
        value = "off"
    }
    env {
        key = "KONG_DECLARATIVE_CONFIG"
        value = "/kong/declarative/kong.yml"
    }
    env {
        key = "KONG_PROXY_ACCESS_LOG"
        value = "/dev/stdout"
    }
    env {
        key = "KONG_ADMIN_ACCESS_LOG"
        value = "/dev/stdout"
    }
    env {
        key = "KONG_PROXY_ERROR_LOG"
        value = "/dev/stderr"
    }
    env {
        key = "KONG_ADMIN_ERROR_LOG"
        value = "/dev/stderr"
    }
    env {
        key = "KONG_ADMIN_LISTEN"
        value = "0.0.0.0:8001, 0.0.0.0:8444 ssl"
    }
  
    port {
        local = 8000
        remote = 8000
        host = 8000       
    }
    port {
        local = 8443
        remote = 8443
        host = 8443       
    }
    port {
        local = 8001
        remote = 8001
        host = 8001       
    }
    port {
        local = 8444
        remote = 8444
        host = 8444       
    }            
}

template "kong-bootstrap" {
    source = <<EOF
#!/bin/bash -x

curl -O -L https://releases.hashicorp.com/vault/1.11.3/vault_1.11.3_linux_arm64.zip
unzip vault_1.11.3_linux_arm64.zip
mv vault /usr/local/bin

curl -O -L https://download.konghq.com/mesh-alpine/kuma-1.8.0-debian-arm64.tar.gz
tar xvzf kuma-1.8.0-debian-arm64.tar.gz
mv /kuma-1.8.0/bin/* /usr/local/bin

export VAULT_TOKEN=$(vault write auth/approle/login role_id=@/kuma/approle/kong-role.id secret_id=@/kuma/approle/kong-role.secret -format=json | jq -r .auth.client_token)
vault read kuma/creds/kong-role -format=json | jq -r .data.token > /kuma/kuma-token-kong

kuma-dp run --cp-address=https://kuma-cp.container.shipyard.run:5678 --dataplane-file=/kuma/dp-config/kong-dp.yml --dataplane-token-file=/kuma/kuma-token-kong --ca-cert-file=/kuma/config/kuma_cp_ca.cert

EOF

destination = "${data("kuma_config/scripts")}/config-kuma-vault.sh"
}

sidecar "kong-tools" {
    target = "container.kong"

    image {
        name = "shipyardrun/tools:v0.7.0"
    }

    command = ["tail", "-f", "/dev/null"]

    volume {
        source      = "./configs/kong/kuma"
        destination = "/kuma/dp-config"
    }

    volume {
        source      = data("kuma_config")
        destination = "/kuma/config"
    }

    volume {
        source      = data("/approles/kong")
        destination = "/kuma/approle"
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
