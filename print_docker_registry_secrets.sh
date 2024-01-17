cat /var/lib/hdci/registry/auth/watchtower/config.json | jq .auths.\"localhost:5000\".auth | sed 's/"//g' | base64 -d
