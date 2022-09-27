---
id: expiry
title: Token Expiry
---

<TerminalVisor>
  <Terminal target="vault-client.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Vault Client" id="vault-client"/>
  <Terminal target="payments.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Payments" id="payments"/>
</TerminalVisor>

For a user, you folow a very similar workflow to an application, you need to authenticate to Vault, and you need token
obtain a token that has policy attached.

Let's use the basic `userpass` auth to see how this works, we are configuring a user login that grants
kuma admin permissions, to illustrate token expiry we are also setting a really short TTL.

```
vault write auth/userpass/users/tom \
  password=secret123 \
  policies=kuma-admins-short-ttl
```

The role that referenced by the kuma-admins-short-ttl looks like this. Note the very short TTL and Max TTL.

```
vault write kuma/roles/kuma-admin-role-short-ttl \
  token_name=tom \
  mesh=default \
  ttl=1m \
  max_ttl=5m \
  groups="mesh-system:admin"
```

If you log into Vault using userpass in the Payments terminal

```
vault login --method=userpass username=tom password=secret123
```

You can then generate a Kuma Control Panel admin token that allows you to interact with the kuma cp, this token is only going to be valid
for the `ttl` period of `1m` specified in the role config.

```
vault read -format=json kuma/creds/kuma-admin-role-short-ttl \
  | jq -r .data.token > /kuma.token
```

Let's test this token

```
curl ${KUMA_URL}/meshes/defaults/secrets \
  -H "authorization: Bearer $(cat /kuma.token)"
```

The first time you run this it should work fine, this is because the token is still valid, however if you wait 1m Vault will automatically add 
the token to Kumas Revocation list, automatically expiring the token.

```
curl ${KUMA_URL}/meshes/defaults/secrets \
  -H "authorization: Bearer $(cat /kuma.token)"
```

```
{
 "title": "Invalid authentication data",
 "details": "Unauthenticated"
}
```

## TODO: 
* Show revocation list
* Explain revocation mechanism and token renewal, max ttl is the token max, ttl is your lease on the token, if tokens are not renewed, they are
revoked.

Using this approach you can worry less about leaking control pane tokens as you are using short time to live, the exact same approach applies
for the control pane tokens that we saw in a previous section.
