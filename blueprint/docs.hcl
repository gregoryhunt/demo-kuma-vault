docs "docs" {
  port = 8080
  open_in_browser = true

  path = "./docs"

  index_title = "Vault Plugin - Kuma"

  image {
    name = "shipyardrun/docs:v0.5.1"
  }

  index_pages = [
    "installing",
    "registration",
    "expiry",
  ]
}
