module "kuma_cp" {
  source = "github.com/gregoryhunt/kuma-blueprint?ref=be90c0ffd3a9b822e131a2264f49c74055467bdb"
}

variable "kuma_cp_network" {
  default     = "local"
  description = "Network name that the Kuma control panel is connected to"
}

copy "files" {
  source      = "./configs/backend.json"
  destination = "${data("kuma_dp")}/dataplane.json"
}

copy "ca" {
  depends_on  = ["module.kuma_cp"]
  source      = "${data("kuma_config")}/kuma_cp_ca.cert"
  destination = "${data("kuma_dp")}/ca.cert"
}

container "kuma_dp" {
  image {
    name = "kumahq/kuma-dp:1.8.0"
  }

  entrypoint = [""]

  command = [
    "tail",
    "-f",
    "/dev/null"
  ]

  volume {
    destination = "/configs"
    source      = data("kuma_dp")
  }

  network {
    name = "network.local"
  }
}