---
id: installing
title: Installing the Plugin
---

<TerminalVisor minimized="true">
  <Terminal target="local" shell="/bin/bash" workdir="/" user="root" name="Local" id="local"/>
  <Terminal target="kuma-cp.container.shipyard.run" shell="/bin/sh" workdir="/" user="root" name="Kuma" id="kuma"/>
  <Terminal target="vault.container.shipyard.run" shell="/bin/sh" workdir="/" user="root" name="Vault" id="vault"/>
</TerminalVisor>


Check the status of Vault

<TerminalRunCommand target="vault">
  <Command>vault status</Command>
</TerminalRunCommand>

```shell
vault status
```
