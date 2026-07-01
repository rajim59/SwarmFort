#!/bin/bash
set -e


openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout site.key -out site.crt \
  -subj "/CN=swarmfort.local/O=SwarmFort/C=BD"


docker secret create site.crt site.crt
docker secret create site.key site.key


rm -f site.crt site.key

echo "TLS secrets created successfully."