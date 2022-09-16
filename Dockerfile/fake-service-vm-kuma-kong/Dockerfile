FROM nicholasjackson/fake-service:vm-v1.12.2-v0.23.1

ARG TARGETARCH

ENV VAULT_VERSION 1.11.3
ENV KUMA_VERSION 1.8.0

COPY supervisor.conf /etc/supervisor/conf.d/fake-service.conf
COPY kong.conf /etc/kong/kong.conf
COPY start-kuma-dp.sh /start-kuma-dp.sh 

RUN chmod +x /start-kuma-dp.sh 

RUN echo "deb [trusted=yes] https://download.konghq.com/gateway-3.x-ubuntu-focal/ default all" | tee /etc/apt/sources.list.d/kong.list

RUN apt update && apt install -y zip nano kong=3.0.0

RUN cd /tmp && \
curl -O -L https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip && \
unzip vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip && \
mv /tmp/vault /usr/local/bin/


RUN cd /tmp && \
curl -O -L https://download.konghq.com/mesh-alpine/kuma-${KUMA_VERSION}-ubuntu-${TARGETARCH}.tar.gz && \
tar --extract --strip-components=2 --file=kuma-${KUMA_VERSION}-ubuntu-${TARGETARCH}.tar.gz kuma-${KUMA_VERSION}/bin/kuma-dp && \
tar --extract --strip-components=2 --file=kuma-${KUMA_VERSION}-ubuntu-${TARGETARCH}.tar.gz kuma-${KUMA_VERSION}/bin/coredns && \
mv /tmp/kuma-dp /usr/local/bin/ && \
mv /tmp/coredns /usr/local/bin/

