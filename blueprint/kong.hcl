container "kong" {
    depends_on = ["module.kuma_cp", "exec_remote.vault_kuma_plugin_configure"]

    network {
        name = "network.local"
    }

    image {
        name = "gregoryhunt/kuma-dp-vault-kong:v0.1.3"
    }

    volume {
        source      = "./configs/kong/kong"
        destination = "/kong/declarative/"
    }
    volume {
        source      = "./configs/kong/kuma"
        destination = "/config"
    }

    volume {
        source      = data("kuma_config")
        destination = "/kuma/config"
    }

    volume {
        source      = data("/approles/kong")
        destination = "/etc/vault/approle"
    }

    volume {
        source      = data("vault/agent/kong")
        destination = "/etc/vault"
    }
    env {
        key   = "VAULT_ADDR"
        value = "http://vault.container.shipyard.run:8200"
    }

    port {
        local = 8000
        remote = 8000
        host = 8000       
        open_in_browser = "/ui"
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

template "kong-vault-agent-config" {
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
    contents     = "{{ with secret \"kuma/creds/kong-role\" }}{{ .Data.token }}{{ end }}"
    destination  = "/etc/vault/kuma-dataplane-token"
}   

EOF

    destination = "${data("vault/agent/kong")}/agent-config.hcl"
}