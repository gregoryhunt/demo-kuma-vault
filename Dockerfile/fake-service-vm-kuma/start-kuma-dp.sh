#!/bin/bash

/usr/local/bin/vault agent -config=/etc/vault/agent-config.hcl &

sleep 1

/usr/local/bin/kuma-dp run --cp-address=https://kuma-cp.container.shipyard.run:5678 --dataplane-file=/config/kuma-dp-config.yml --dataplane-var address=`hostname -I | awk '{print $1}'` --dataplane-token=$(cat /etc/vault/kuma-dataplane-token) --ca-cert-file=/kuma/config/kuma_cp_ca.cert &

/app/fake-service
