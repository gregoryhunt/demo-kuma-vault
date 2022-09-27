container "payments" {
    depends_on = ["module.kuma_cp", "exec_remote.vault_kuma_plugin_configure"]

    network {
        name = "network.local"
    }

    image {
        name = "gregoryhunt/kuma-dp-vault:v0.1.3"
    }

    volume {
        source      = "./configs/payments"
        destination = "/config"
    }
   
    # Override the startup script for the guide VM
    # everything will be manually started
    volume {
        source      = "./supervisor/payments"
        destination = "/etc/supervisor/conf.d"
    }

    volume {
        source      = data("kuma_config")
        destination = "/kuma/config"
    }

    volume {
        source      = data("/approles/payments")
        destination = "/etc/vault/approle"
    }

    env {
        key   = "VAULT_ADDR"
        value = "http://vault.container.shipyard.run:8200"
    }
    
    env {
        key   = "KUMA_URL"
        value = "http://kuma-cp.container.shipyard.run:5681"
    }

    env {
        key = "LISTEN_ADDR"
        value = "127.0.0.1:9091"
    }
    env {
        key = "NAME"
        value = "Payments"
    }

    port {
        local = 9094
        remote = 9094
        host = 9094       
    }         
}
