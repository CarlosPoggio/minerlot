FROM debian:bookworm-slim AS fetch

ARG BITCOIN_VERSION=31.1
ARG BITCOIN_SHA256=b80d9c3e04da78fb6f0569685673418cf686fadba9042d926d13fb87ff503f9e

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN curl -fsSLO https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz \
    && echo "${BITCOIN_SHA256}  bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" | sha256sum -c - \
    && tar -xzf bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz \
    && mv bitcoin-${BITCOIN_VERSION} /bitcoin

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends libevent-2.1-7 libevent-pthreads-2.1-7 libzmq5 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -u 1000 -m -d /home/bitcoin bitcoin \
    && mkdir -p /home/bitcoin/.bitcoin \
    && chown -R bitcoin:bitcoin /home/bitcoin

COPY --from=fetch /bitcoin/bin/bitcoind /usr/local/bin/bitcoind
COPY --from=fetch /bitcoin/bin/bitcoin-cli /usr/local/bin/bitcoin-cli

USER bitcoin
VOLUME ["/home/bitcoin/.bitcoin"]
EXPOSE 8332 8333 3000

ENTRYPOINT ["bitcoind", "-datadir=/home/bitcoin/.bitcoin"]
