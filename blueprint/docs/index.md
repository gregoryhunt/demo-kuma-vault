---
id: installing
title: Installing and Configuring the Plugin
---

<TerminalVisor>
  <Terminal target="local" shell="/bin/bash" workdir="/" user="root" name="Local" id="local"/>
  <Terminal target="kuma-cp.container.shipyard.run" shell="/bin/sh" workdir="/" user="root" name="Kuma" id="kuma"/>
  <Terminal target="vault-client.container.shipyard.run" shell="/bin/sh" workdir="/" user="root" name="Vault Client" id="vault-client"/>
  <Terminal target="vault.container.shipyard.run" shell="/bin/sh" workdir="/" user="root" name="Vault Server" id="vault-server"/>
</TerminalVisor>


Check the status of Vault

<TerminalRunCommand target="vault-client">
  <Command>vault status</Command>
</TerminalRunCommand>

```shell
vault status
```

## Register the plugin

To use custom plugins in Vault they need to be registered with the system, the following command registers the plugin
with Vault. We are registering using the checksum of the plugin binary to ensure that the plugin can not be replaced 
with a fake version that provides different functionality.

```shell
vault write sys/plugins/catalog/secret/vault-plugin-kuma \
    sha_256="$(sha256sum /plugins/vault-plugin-kuma-linux-amd64 | cut -d " " -f 1)" \
    command="vault-plugin-kuma-linux-amd64"
```

## Enable the plugin at a path

To use a plugin you need to enable it, since everything in Vault is path based, we reference the path
that will allow us to use the plugin.

```shell
vault secrets enable -path=kuma vault-plugin-kuma
```

## Configure the plugin

Finally before we can use a plugin it needs to be configured. The plugin needs to be configured with the 
`URL` of the Kuma control plane and also a valid `admin` token that can be used to perform API operations.

Vault will use both of these pieces of info to generate and manage Kuma tokens on your behalf.

```
vault write kuma/config url=$KUMA_URL token=@$KUMA_TOKEN
```

## Generating tokens
