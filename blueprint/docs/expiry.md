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

```
{
 "total": 0,
 "items": [],
 "next": null
}
```

The first time you run this it should work fine, this is because the token is still valid, however if you wait 1m Vault will automatically add 
the token to Kumas Revocation list, automatically expiring the token.

```
curl ${KUMA_URL}/meshes/default/secrets \
  -H "authorization: Bearer $(cat /kuma.token)"
```

```
{
 "title": "Invalid authentication data",
 "details": "Unauthenticated"
}
```

When a token is revoked it is automatically added to the revocation list

```
curl ${KUMA_URL}/global-secrets/user-token-revocations  \
  -H "authorization: Bearer $(cat /kuma.token)" \
  | jq -r .data \
  | base64 -d
```

If you decode the list you will see the jti's as a comma separated list. Vault will automatically clean up this list once the TTL on the original token expires.

```
cb269cc9-d348-429b-8efb-0a914d9364d9,789f31c1-1c1d-4f1a-89d2-bd75dfb61460,0437d4e6-531c-4a21-a290-4e46d70b10e7,1f4f4ab5-ce9
```

As an operator Vault you can manually revoke a token at any time, if you realise something has leaked then 
this capability allows you to revoke  things.
