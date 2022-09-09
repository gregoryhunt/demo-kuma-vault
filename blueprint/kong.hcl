


/*
container "kong-pg" { 
    network {
        name = "network.local"
    }

    image {
        name = "postgres:9.6"
    }

    env {
        key = "POSTGRES_USER"
        value = "kong"
    }
    env {
        key = "POSTGRES_DB"
        value = "kong"
    }
    env {
        key = "POSTGRES_PASSWORD"
        value = "kongpass"
    }

    port {
        local = 5432
        remote = 5432
        host = 5432
    }
}

exec_remote "kong-pg-init" {
    depends_on = ["container.kong-pg"]

    image {
        name = "kong:2.8.1-alpine"
    }

    network {
        name = "network.local"
    }

    cmd = "kong"
    args = [
        "migrations",
        "bootstrap"
    ]

    env {
        key = "KONG_DATABASE"
        value = "postgres"
    }
    env {
        key = "KONG_PG_HOST"
        value = "kong-pg.container.shipyard.run"
    }
    env {
        key = "KONG_PG_PASSWORD"
        value = "kongpass"
    }
}

*/
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

