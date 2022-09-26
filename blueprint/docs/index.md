---
id: installing
title: Installing and Configuring the Plugin
---

<TerminalVisor>
  <Terminal target="local" shell="/bin/bash" workdir="/" user="root" name="Local" id="local"/>
  <Terminal target="kuma-cp.container.shipyard.run" shell="/bin/sh" workdir="/" user="root" name="Kuma" id="kuma"/>
  <Terminal target="vault-client.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Vault Client" id="vault-client"/>
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
    sha_256="$(sha256sum /plugins/vault-plugin-kuma | cut -d " " -f 1)" \
    command="vault-plugin-kuma"
```

## Enable the plugin at a path

To use a plugin you need to enable it, since everything in Vault is path based, we reference the path
that will allow us to use the plugin.

```shell
vault secrets enable -path=kuma-guide vault-plugin-kuma
```

## Configure the plugin

Finally before we can use a plugin it needs to be configured. The plugin needs to be configured with the 
`URL` of the Kuma control plane and also a valid `admin` token that can be used to perform API operations.

Vault will use both of these pieces of info to generate and manage Kuma tokens on your behalf.

```shell
vault write kuma-guide/config url=$KUMA_URL token=@$KUMA_TOKEN
```

## Generating tokens

To generate tokens you first need to create a role, a role defines the permissions that the generated token will have.
In the following example we are going to create a role that generates admin tokens.  

```shell
vault write kuma-guide/roles/kuma-admin-role \
  token_name=jerry \
  mesh=default \
  ttl=1h \
  max_ttl=24h \
  groups="mesh-system:admin"
```

Now this has been created we can generate a token, to generate a Kuma token you first need a Vault token that has permission to
use the role. We will look at how to do that in a moment but for now, let's check that Vault can generate Kuma tokens for us.

```shell
vault write -force kuma-guide/creds/kuma-admin-role
```

The response will look something like the following, let's test that the token works by making a call to the Kuma control pane API.

```shell
Key                Value
---                -----
lease_id           kuma-guide/creds/kuma-admin-role/u8LuR60iV7ZJ0jS0xYGjQJAy
lease_duration     1h
lease_renewable    true
token              eyJhbGciOiJSUzI1NiIsImtpZCI6IjEiLCJ0eXAiOiJKV1QifQ.eyJOYW1lIjoiamVycnkiLCJHcm91cHMiOlsibWVzaC1zeXN0ZW06YWRtaW4iXSwiZXhwIjoxNjY0Mjg5ODQ1LCJuYmYiOjE2NjQyMDMxNDUsImlhdCI6MTY2NDIwMzQ0NSwianRpIjoiZjMyNmU3ZDUtMDI0NC00MWRhLTlhNjgtNGQwNWQyNmQ0MGYwIn0.oRKlvAQMNd8ytgHahcR7VBOkS9Y-Ir9qf0I41vy8mL68OZatanLdR3QnOomF-8TJ8USV3W8DPi9iRpjs7c3FJL_4qsBHI19ZH37C2RxZJvYUJMefZWszSnuwlccvNns6YRMTAu_4DRfIZgYwR3T2Wn6shMyVkQu92cxHCBoaoL-9aiRtvmVSCovglXPGwJ_PpXM53TbdBFtAvTtwnqrVSez4Amp6C4nKGqdy0AuXdQ-mHHmpeHfVFLlMPxwBfoNopf-NfucH6pbehaWyJhN4uDJjNnboJXltFl4l_oacIOeDclO93dG4nmQQUU4SsRainUVcCUZCDWFk8bWYS9DdfA
```

You need to grab the contents of the `token` section, this can then be used in a call to the Kuma API like so.

```
curl ${KUMA_URL}/meshes/defaults/secrets -H "authorization: Bearer <your_token>"
```

If the request worked you should see something like the following:

```
{
 "total": 0,
 "items": [],
 "next": null
}
```

Now you have seen the basics of creating user tokens, let's now see how we can use Vault to automatically provision tokens for
VMs so that they can register themselfs with Kuma.

<p style={{height: '400px'}}></p>
