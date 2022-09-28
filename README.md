# demo-kuma-vault
Demo for leveraging Hashicorp Vault to manage Tokens in Kuma

## Running the Demo Application

The example application can be run locally using Docker and Shipyard. It runs a simulated environment that
consists of several Virtual Machines and a Kong API Gateway and Kuma Service Mesh.

Shipyard is a single binary application that allows the automation of complex environments using Docker. It is kind
of like if Docker Compose and Terraform had a child.

(https://shipyard.run/docs/install)[https://shipyard.run/docs/install]

Once Shipyard is installed you can run the example using the following command:

```shell
shipyard run ./blueprint
```
