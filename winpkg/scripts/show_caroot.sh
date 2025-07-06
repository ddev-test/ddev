#!/bin/bash
set -eu -o pipefail
echo "id"
id
echo "mkcert -CAROOT"
mkcert -CAROOT

echo CAROOT:
echo "$CAROOT"