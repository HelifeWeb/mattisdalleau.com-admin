#!/bin/bash
print_secret() {
	file="./docker-data/hdci/static-configurations/auth/$1/.non-encrypted.b64"
	data=$(cat "$file" | base64 -d)

	if [ -z "$data" ]; then
		echo "No non-encrypted secrets found for $1" 1>&2
		return
	fi

	echo "===================="
	echo
	echo
	echo "$1:"
	echo "  User:     '$(echo "$data" | cut -d ':' -f 1)'"
	echo "  Password: '$(echo "$data" | cut -d ':' -f 2)'"
	echo
	echo "Do not forget to remove "
	echo "         'rm -f $file'"
	echo "in a production environment after storing it safely"
	echo
	echo

}

print_secret "rev-proxy/portainer"
print_secret "private/registry"
