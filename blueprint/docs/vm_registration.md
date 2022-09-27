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

Let's manually test the policy, we can use the AppRole credentials that have already been provisioned to the Payments service
to test the login

```
vault write auth/approle/login \
   role_id=$(cat /etc/vault/approle/roleid)  \
   secret_id=$(cat /etc/vault/approle/secretid)
```

```

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
export VAULT_TOKEN=$(vault write --format=json auth/approle/login role_id=$(cat /etc/vault/approle/roleid) secret_id=$(cat /etc/vault/approle/secretid) | jq -r .auth.client_token)
```

```
vault read kuma-guide/creds/payments-role
```

```
Key                Value
---                -----
lease_id           kuma-guide/creds/payments-role/6ootjdXQDLDHS70ftMl9IEWn
lease_duration     1h
lease_renewable    true
token              eyJhbGciOiJSUzI1NiIsImtpZCI6IjEiLCJ0eXAiOiJKV1QifQ.eyJOYW1lIjoicGF5bWVudHMiLCJNZXNoIjoiZGVmYXVsdCIsIlRhZ3MiOnsia3VtYS5pby9zZXJ2aWNlIjpbInBheW1lbnRzIl19LCJUeXBlIjoiZGF0YXBsYW5lIiwiZXhwIjoxNjY0MzYxNTc5LCJuYmYiOjE2NjQyNzQ4NzksImlhdCI6MTY2NDI3NTE3OSwianRpIjoiZjU2Yzc5MjktZjIwYy00MDJlLTlhZGItNzkyMWM3NDY4ZTUyIn0.kyfzIJSxsBj8q-0Zm7WZO1ge6CEyPss7LgMILxFonAqZnlnXYg9hg-2U43j5_7EXldhvC0bMAYVA034a-C4V3yS3utvn0gF6-5JV-8D9CYUtQJtwm2Oh5AR1KZk2XWgOrxSP6JuiOOATCma0lS6XI2XsxvSbRA_uD1emR0vJK8kjHREm_qqDwT4MfS36Bs2fBswl3UcGQJmXCiBuiR9oyI2V2CyOI_PcepEP95H7EXaWtn4CY38GfSx4kJoerWdPe7IGboV1AB8MQTO_HmWyAENsbh-XzU5p9aAlq_og1YdYrfYxeJjWZNDE63uynsZnD00jqK-VPvz-2dQxFBPBhw
```

If you run this again but this time trying to use another role, you will get permission denied as your token does not 
have access to this policy.

```
vault read kuma-guide/creds/api-role
```

```
Error reading kuma-guide/creds/api-role: Error making API request.

URL: GET http://vault.container.shipyard.run:8200/v1/kuma-guide/creds/api-role
Code: 403. Errors:

* 1 error occurred:
        * permission denied
```

## Pulling this together using Vault Agent

This demonstrates the manual approach for authenticating and creating a token, however you can use Vault Agent to do this automatically 
for you. Generally Vault Agent is run as a system job on your virtual machine.

To use Vault Agent you need a template, create a new file with the contents of this block

```
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
    contents     = "{{ with secret \"kuma-guide/creds/payments-role\" }}{{ .Data.token }}{{ end }}"
    destination  = "/etc/vault/kuma-dataplane-token"
} 
```

```
nano /etc/vault/agent-config.hcl
```

You can then start Vault Agent using the following command

```
/usr/local/bin/vault agent -config=/etc/vault/agent-config.hcl &
```

Vault Agent will automatically login using the AppRole credentials and will request a Kuma token from Vault. You will see this token has been written
to the destination defined in the template.

```
cat /etc/vault/kuma-dataplane-token
```

## Starting the Dataplane

Now that we have the token, we can start the dataplane and allow it to register the payments service, run the following command in the Payments
terminal.

```
/usr/local/bin/kuma-dp run \
  --cp-address=https://kuma-cp.container.shipyard.run:5678 \
  --dataplane-file=/config/kuma-dp-config.yml \
  --dataplane-var address=`hostname -I | awk '{print $1}'` \
  --dataplane-token=$(cat /etc/vault/kuma-dataplane-token) \
  --ca-cert-file=/kuma/config/kuma_cp_ca.cert &
```

If you look at the Kuma Control Panel you will see that the Dataplane has been correctly registered and the service correctly registered.

That is all for data plane tokens, let's look at how Vault manages token expiry and how users can obtain Kuma Control Pane tokens.

<p style={{height: '400px'}}></p>
