---
id: registration
title: Automatically Generating Tokens for Data Plane Registration
---

<TerminalVisor>
  <Terminal target="vault-client.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Vault Client" id="vault-client"/>
  <Terminal target="payments.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Payments" id="payments"/>
</TerminalVisor>

In this section you will learn how to use Vault Agent to automatically obtain Kuma Tokens that allow you to register a Kuma
data plane for your application services.

Kuma uses tightly scoped tokens that allow a dataplane to be connected to the control pane and for a service to be registered. Since Vault 
is providing the tokens you first need to authenticate to Vault so that Vault can validate the identity of the application ensuring that
it has the correct permission to obtain the required token.

Vault has many different auth methods such as cloud metadata x509 certificates, JWT, however for arbirary logins there is also AppRole that uses 
a specific application id to identify your application and a secret. These two pieces of info can be used to authenticate against Vault and to 
obtain a Toke that has permission to generate Kuma CP tokens. AppRole Credentials are commonly added to a Virtual Machine at deploy time
this can be as part of your provisioning scripts with Terraform or application configuration if using a tool like Ansible. The AppRole defines
the identity of your application and is specific to it. Commonly when deploying to a cloud environment you would not use AppRole but using 
cloud provided machine identity such as AWS IAM, Azure Service Principle, or GCP IAM. Vault supports many different auth methods, we are
using AppRole for this demo as it allows us to have a setup that is independent and self contained.

[https://www.vaultproject.io/docs/auth](https://www.vaultproject.io/docs/auth)

## Creating the role

You learned in the previous section that the Role in Vault configures the parameters for the token that will be generated. When generating
Kuma tokens for your applications you will mostly likely want a 1-1 mapping between appliction and role. This is so that you can tightly
scope the permissions of each generated token and to keep the blast radius of any leaked token to a very narrow scope.

In this instance, since we want to register the `payments` service, we need to create a role that has the `tags`, `kuma.io/service=payments`.
We are setting a lease `ttl` of one hour and a maximum token `ttl` of one week. Since the token renewal is going to be automatically managed
these settings should give enough balance between token churn and the risk of the token falling into the wrong hands. Vault allows you to 
fine tune these parameters based on the needs for your system.  If you set the ttl two low then this increases the load on the Vault server
as it constantly needs to respond to lease renewal requests. If you set the `max_ttl` too low then Kuma constantly needs to generate new
tokens and your dataplane needs to be restarted to use the new token.

Run this command in the Vault Client terminal below:

<TerminalRunCommand target="vault-client">
  <Command>vault write kuma-guide/roles/payments-role \
  token_name=payments \
  mesh=default \
  ttl=1h \
  max_ttl=168h \
  tags="kuma.io/service=payments"</Command>
</TerminalRunCommand>

```shell
vault write kuma-guide/roles/payments-role \
  token_name=payments \
  mesh=default \
  ttl=1h \
  max_ttl=168h \
  tags="kuma.io/service=payments"
```

## Creating policy

To determine which roles and secrets that a user or applicaton can use Vault has the concept of policy. Policy defined specifically what
secrets or operations an application or individul has access to. For example the `Payments` application requires the ability to generate
Kuma Tokens, you can write policy that grants this specific capability. However it is common that the application may also use other 
secrets provided by Vault such as Database Credentials or Static Secrets. Fine grained policy can be written that tightly controls access
 to only the requrired secrets.

When the AppRole credentials were configured for the payments service, the policies `default` and `payments` were associated with
this identity. This means that when these credentials were used to authenticate with Vault a Vault token would be returne that would
have the permission to perform actions and obtain secrets that are only defined by these policies.  

Configuring authentication methods is beyond the scope fo this guide but as an example, the following command was used to congfigure
the Payments service AppRole credentials.

*example approle configuration*

```
vault write auth/approle/role/payments-role \
  token_ttl=30m \
  token_max_ttl=60m \
  token_policies=default,payments \
  bind_secret_id=true
```

`default` is the default policy in Vault, it does not define access to any secrets but only defines simple capabilities such as the abiltiy
to discover the details about your own Vault Token and to be able to perform actions such as renewing the lease on a secret that you have
created.

The `payments` policy does not yet exist, let's create the policy that will provide access to the kuma-guide/roles/payments-role. Policy document 
in Vault are written in HCL and define the `path` that you have access to and the `capabilies` you have on that path. In this example
the path is `kuma-guide/creds/payments-role` which is the Vault path for creating a the Kuma token and the capabilies are `read`. This loosely
translates to an API call of HTTP GET to the Vault API `/v1/kuma-guide-creds/payments-role`. This policy would NOT allow you to create
AppRoles as performed in the previous `vault write`.

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

<TerminalRunCommand target="vault-client">
  <Command>vault policy write payments ./payments_policy.hcl</Command>
</TerminalRunCommand>

```
vault policy write payments ./payments_policy.hcl
```

Let's manually test the policy, we can use the AppRole credentials that have already been provisioned to the Payments service
to test the login. You will need to switch to the `Payments` terminal before running this command.

<TerminalRunCommand target="payments">
  <Command>vault write auth/approle/login \
   role_id=$(cat /etc/vault/approle/roleid)  \
   secret_id=$(cat /etc/vault/approle/secretid)</Command>
</TerminalRunCommand>

```shell
vault write auth/approle/login \
   role_id=$(cat /etc/vault/approle/roleid)  \
   secret_id=$(cat /etc/vault/approle/secretid)
```

```shell
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

Rather than copy and pasing the token, you can use a simlar technique to the previous section to export the token to an environment variable.

<TerminalRunCommand target="payments">
  <Command>export VAULT_TOKEN=$(vault write --format=json auth/approle/login role_id=$(cat /etc/vault/approle/roleid) secret_id=$(cat /etc/vault/approle/secretid) | jq -r .auth.client_token)</Command>
</TerminalRunCommand>

```
export VAULT_TOKEN=$(vault write --format=json auth/approle/login role_id=$(cat /etc/vault/approle/roleid) secret_id=$(cat /etc/vault/approle/secretid) | jq -r .auth.client_token)
```

You can then run the following command to generate the token.

<TerminalRunCommand target="payments">
<Command>vault read kuma-guide/creds/payments-role</Command>
</TerminalRunCommand>

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

If you run this again but this time trying to use another existing role, you will get permission denied as your token does not 
have access to this policy.

<TerminalRunCommand target="payments">
<Command>vault read guide/creds/api-role</Command>
</TerminalRunCommand>

```shell
vault read guide/creds/api-role
```

```shell
Error reading kuma-guide/creds/api-role: Error making API request.

URL: GET http://vault.container.shipyard.run:8200/v1/kuma-guide/creds/api-role
Code: 403. Errors:

* 1 error occurred:
        * permission denied
```

This demonstrates the manual approach for authenticating and creating a token, however you can use Vault Agent to do this automatically 
for you. Generally Vault Agent is run as a system job on your virtual machine.

## Pulling this together using Vault Agent

Vault Agent is a simple command that is built into the Vault CLI. It is configured using templates that allow you to congfiure the authentication
parameters as well as the ability to ouput secrets to files or generate application specific configuration.

[https://www.vaultproject.io/docs/agent](https://www.vaultproject.io/docs/agent)

To configure Vault Agent to automatically authenticate to Vault using the AppRole credentials and to generate and manage the lifecycle of a
Kuma Token that can be used to register a Kuma Dataplane the following template could be written.

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

Create a new file in the `Payments` terminal with the contents of the previous code block and save it to `/etc/vault/agent-config.hcl`.

<TerminalRunCommand target="payments">
<Command>nano /etc/vault/agent-config.hcl</Command>
</TerminalRunCommand>

```
nano /etc/vault/agent-config.hcl
```

You can then start Vault Agent using the following command. Commonly you would configure systemd or another daemon manager to run this as it needs
to be a long lived application. Vault Agent will continual monitor the lifecyle of the Kuma Token, renewing it as necessary.

<TerminalRunCommand target="payments">
<Command>/usr/local/bin/vault agent -config=/etc/vault/agent-config.hcl &</Command>
</TerminalRunCommand>

```
/usr/local/bin/vault agent -config=/etc/vault/agent-config.hcl &
```

Vault Agent will automatically login using the AppRole credentials and will request a Kuma token from Vault. You will see this token has been written
to the destination defined in the template.

<TerminalRunCommand target="payments">
<Command>cat /etc/vault/kuma-dataplane-token</Command>
</TerminalRunCommand>

```
cat /etc/vault/kuma-dataplane-token
```

## Starting the Dataplane

Now that we have the token, we can start the dataplane and allow it to register the payments service, run the following command in the Payments
terminal.

<TerminalRunCommand target="payments">
<Command>/usr/local/bin/kuma-dp run \
  --cp-address=https://kuma-cp.container.shipyard.run:5678 \
  --dataplane-file=/config/kuma-dp-config.yml \
  --dataplane-var address=$(hostname -I) \
  --dataplane-token=$(cat /etc/vault/kuma-dataplane-token) \
  --ca-cert-file=/kuma/config/kuma_cp_ca.cert &
</Command>
</TerminalRunCommand>

```shell
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
