---
id: registration
title: Automatically Generating Tokens for Data Plane Registration
---

<TerminalVisor>
  <Terminal target="local" shell="/bin/bash" workdir="/" user="root" name="Local" id="local"/>
  <Terminal target="kuma-cp.container.shipyard.run" shell="/bin/sh" workdir="/" user="root" name="Kuma" id="kuma"/>
  <Terminal target="vault-client.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Vault Client" id="vault-client"/>
  <Terminal target="payments.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Payments" id="payments"/>
</TerminalVisor>

To register services with the Kuma Control Plane and to run a Kuma Data Plane you need an access token for the registration.

Since Vault is providing the tokens you first need to authenticate to Vault, Vault has many different auth methods such as cloud metadata
x509 certificates, JWT, however for arbirary logins there is AppRole that uses a specific application id to identify your application
and a secret. These two pieces of info can be used to authenticate against Vault and to obtain a Token that has permission to generate
Kuma CP tokens.

* Mention how Tokens end up on box (provisioning time)
* Mention use cloud metadata where possible

Rather than a manual process you can use a tool called Vault Template that is responsible for authenticating and then fetching the token,
we are going to walk through these steps one by one to enable control plane registration for our Payments service.

## Creating the role

To register a token with the control pane you need a token that has the correct permissions, in this instance, since we want to 
register the `payments` service, we need to create a role that has the `tags`, `kuma.io/service=payments`.

Run this command in the Vault Client terminal below:

```shell
vault write kuma-guide/roles/payments-role \
  token_name=payments \
  mesh=default \
  ttl=1h \
  max_ttl=24h \
  tags="kuma.io/service=payments"
```

## Creating policy

With Vault every secret that you have access to is controlled by policy, it is fine grained control allowing different tokens to have 
different capabilities.

When the approle was configured for the payments service, it was specified that on successful authentication a token would be returned
that had the permissions of the `default` and `payments` policy.


*example approle configuration*

```
vault write auth/approle/role/payments-role \
  token_ttl=30m \
  token_max_ttl=60m \
  token_policies=default,payments \
  bind_secret_id=true
```

Let's create the policy that will provide access to the kuma-guide/roles/payments-role. You do that by authoring a policy document in HCL
that looks like the following. Note the path, all access in Vault is a path, while `auth/approle/role/payments-role` is the path for configuring
a role. The corresponding path that allows you to generate credentials is `kuma-guide/creds/payments-role`.

```
path "kuma-guide/creds/payments-role" {
  capabilities = ["read"]
}
```

Run the following command to create the policy in the `Vault Client` terminal.

```
cat <<EOF > ./payments_policy.hcl
path "kuma-guide/creds/payments-role" {
  capabilities = ["read"]
}
EOF
```

Now you can register this policy file with Vault

```
vault policy write payments ./payments_policy.hcl
```

Let's manually test the policy

```
vault token create -policy=payments -policy=default
```

```
Key                  Value
---                  -----
token                hvs.CAESIP55IfruxPqXu4NYXoypFQlCZy6GcfcWhpLJhRSkGl-BGh4KHGh2cy43VTFGeUlsT1RMZktVa1ozY0RnVW5vSzE
token_accessor       dDnIkBFowA7NCtEzu68YbR0w
token_duration       768h
token_renewable      true
token_policies       ["default" "payments"]
identity_policies    []
policies             ["default" "payments"]
```

You can grab the token returned from the previous command and use it like so to check that the token has the correct permissions to generate a 
Kuma token for the payments service.

```
VAULT_TOKEN=<your_token> vault write kuma-guide/creds/payments-role
```

If you run this again but this time trying to use another role, you will get permission denied as your token does not 
have access to this policy.

```
VAULT_TOKEN=<your_token> vault write kuma-guide/creds/api-role
```

<p style={{height: '400px'}}></p>
