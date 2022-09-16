container "api" {
    depends_on = ["module.kuma_cp", "exec_remote.vault_kuma_plugin_configure"]

    network {
        name = "network.local"
    }

    image {
        name = "gregoryhunt/kuma-dp-vault:v0.1.3"
    }

    volume {
        source      = "./configs/api"
        destination = "/config"
    }

    volume {
        source      = data("kuma_config")
        destination = "/kuma/config"
    }

    volume {
        source      = data("/approles/api")
        destination = "/etc/vault/approle"
    }

    volume {
        source      = data("vault/agent/api")
        destination = "/etc/vault"
    }
    env {
        key   = "VAULT_ADDR"
        value = "http://vault.container.shipyard.run:8200"
    }

    env {
        key = "LISTEN_ADDR"
        value = "127.0.0.1:9090"
    }
    
    env {
        key = "UPSTREAM_URIS"
        value = "localhost:39091"
    }

    env {
        key = "NAME"
        value = "api"
    }

    port {
        local = 9090
        remote = 9090
        host = 9090       
    }         
}

template "api-vault-agent-config" {
    source = <<EOF
pid_file = "./pidfile"

auto_auth {
    method {
        type = "approle"

        config = {
            role_id_file_path = "/etc/vault/approle/roleid"
            secret_id_file_path = "/etc/vault/approle/secretid"
            remove_secret_id_file_after_reading = false
        }
    }
}

template {
    contents     = "{{ with secret \"kuma/creds/api-role\" }}{{ .Data.token }}{{ end }}"
    destination  = "/etc/vault/kuma-dataplane-token"
}   

EOF

    destination = "${data("vault/agent/api")}/agent-config.hcl"
}