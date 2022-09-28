---
id: expiry
title: Token Expiry
---

<TerminalVisor>
  <Terminal target="vault-client.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Vault Client" id="vault-client"/>
  <Terminal target="payments.container.shipyard.run" shell="/bin/bash" workdir="/" user="root" name="Payments" id="payments"/>
</TerminalVisor>

In this section you will learn how the Vault Kuma Plugin handles token revocation, we are going to use `user`
tokens as the example but the same principles apply to all tokens.

For a user, you folow a very similar workflow to an application, you need to authenticate to Vault, and you need token
obtain a token that has policy attached.

Let's configure the basic `userpass` auth to see how this works, we are configuring a user login that grants
kuma admin permissions, to illustrate token expiry we are also setting a really short TTL.

<TerminalRunCommand target="vault-client">
  <Command>vault write auth/userpass/users/tom \
  password=secret123 \
  policies=kuma-admin-short-ttl</Command>
</TerminalRunCommand>

```
vault write auth/userpass/users/tom \
  password=secret123 \
  policies=kuma-admins-short-ttl
```

The role that referenced by the kuma-admins-short-ttl looks like this. Note the very short TTL and Max TTL, this is 
deliberately set so we don't have to wait several days for Vault to revoke a token. 
```
vault write kuma/roles/kuma-admin-role-short-ttl \
  token_name=tom \
  mesh=default \
  ttl=1m \
  max_ttl=5m \
  groups="mesh-system:admin"
```

Both this role and the associated policy `kuma-admin-short-ttl` have already been configure, you can see them by 
running the following commands.

<TerminalRunCommand target="vault-client">
  <Command>vault policy read kuma-admins-short-ttl</Command>
  <Command>vault read kuma/roles/kuma-admin-role-short-ttl</Command>
</TerminalRunCommand>

```shell
vault policy read kuma-admins-short-ttl
vault read kuma/roles/kuma-admin-role-short-ttl
```

Let's log into Vault using UserPass auth created earlier in the Payments terminal.

<TerminalRunCommand target="payments">
  <Command>vault login --method=userpass username=tom password=secret123</Command>
</TerminalRunCommand>

```
vault login --method=userpass username=tom password=secret123
```

You can then generate a Kuma Control Panel admin token that allows you to interact with the kuma cp, this token is only going to be valid
for the `ttl` period of `1m` specified in the role config. Let's use jq to extract the token and write this to a file for easier use.

<TerminalRunCommand target="payments">
  <Command>vault read -format=json kuma/creds/kuma-admin-role-short-ttl \
  | jq -r .data.token > /kuma.token</Command>
</TerminalRunCommand>

```
vault read -format=json kuma/creds/kuma-admin-role-short-ttl \
  | jq -r .data.token > /kuma.token
```

Now we have the token we can use it to make a call to the Kuma API and query the secrets for the `default` service mesh.

<TerminalRunCommand target="payments">
  <Command>curl $KUMA_URL/meshes/defaults/secrets \
  -H "authorization: Bearer $(cat /kuma.token)"</Command>
</TerminalRunCommand>

```
curl ${KUMA_URL}/meshes/defaults/secrets \
  -H "authorization: Bearer $(cat /kuma.token)"
```

You should see output something like the following, there are currently no secrets but the request has been authenticated.

```
{
 "total": 0,
 "items": [],
 "next": null
}
```

The first time you run this it should work fine, this is because the token is still valid, however if you wait 1m Vault will automatically add 
the token to Kumas Revocation list, automatically expiring the token. Let's wait one minute and then try this again.

<TerminalRunCommand target="payments">
  <Command>curl $KUMA_URL/meshes/defaults/secrets \
  -H "authorization: Bearer $(cat /kuma.token)"</Command>
</TerminalRunCommand>

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

The token that was generated has a `max_ttl` of 5 minutes, that means the JWT would have an exiration set that was 5 minutes later than the creation
date. To expire tokens early in Kuma you need to add them to the token revocations secrets, this is a comma separated set of token identifiers. Kuma
always checks this list when a user makes a request, any token on this list is treated as expired. Since Vault allows a lease to be defined
for a token (the ttl), if a lease is not renewed it will assume that the token is no longer being used and should it have not expired, it automatically
adds the tokens JTI to the revocation secret. This is what you just saw when you waited 1 minute and tried to make another request, it failed
because Vault had automatically revoked the token.

Let's look at the revocation list and you will see the token in there, first you need to generate a new token, then we can examine the
`user-token-revocation global secret.

<TerminalRunCommand target="payments">
  <Command>vault read -format=json kuma/creds/kuma-admin-role-short-ttl \
  | jq -r .data.token > /kuma.token</Command>
  <Command>curl $KUMA_URL/global-secrets/user-token-revocations  \
  -H "authorization: Bearer $(cat /kuma.token)" \
  | jq -r .data \
  | base64 -d</Command>
</TerminalRunCommand>

```
vault read -format=json kuma/creds/kuma-admin-role-short-ttl \
  | jq -r .data.token > /kuma.token

curl ${KUMA_URL}/global-secrets/user-token-revocations  \
  -H "authorization: Bearer $(cat /kuma.token)" \
  | jq -r .data \
  | base64 -d
```

If you decode the list you will see the JTI's as a comma separated list. Vault will automatically clean up this list once the TTL on the original token expires.

```
cb269cc9-d348-429b-8efb-0a914d9364d9,789f31c1-1c1d-4f1a-89d2-bd75dfb61460,0437d4e6-531c-4a21-a290-4e46d70b10e7,1f4f4ab5-ce9
```

As an operator Vault you can manually revoke a token at any time, if you realise something has leaked then 
this capability allows you to revoke things. For more information on this capability please see the Vault documentation.

[https://www.vaultproject.io/docs/concepts/lease](https://www.vaultproject.io/docs/concepts/lease)

Using this approach you can worry less about leaking control pane tokens as you are using short time to live, the exact same approach applies
for the control pane tokens that we saw in a previous section.
