FROM ghcr.io/luxxy-gf/pterodactyl-fivem:latest

USER root
COPY srp-entrypoint.sh /usr/local/bin/srp-entrypoint.sh
RUN chmod +x /usr/local/bin/srp-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/srp-entrypoint.sh"]
