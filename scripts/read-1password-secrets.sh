#!/bin/bash

# Read secrets into environment from 1password

for item in DDEV_ACQUIA_API_KEY DDEV_ACQUIA_API_SECRET DDEV_PANTHEON_API_TOKEN DDEV_PLATFORM_API_TOKEN DDEV_UPSUN_API_TOKEN; do
  type=credential
  printf "export ${item}=$(op item get ${item} --field=credential --reveal)\n"
done
