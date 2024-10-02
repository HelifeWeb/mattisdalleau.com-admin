#!/bin/bash
print_secret() {
	file="./data/hdci/auth/$1/.non-encrypted"
	data=$(cat "$file" | base64 -d)

	if [ -z "$data"]; then
		echo "No non-encrypted secrets found for $1" 1>&2
		return
	fi

	echo "$1:"
	echo "  User:     '$(echo "$data" | cut -d ':' -f 1)'"
	echo "  Password: '$(echo "$data" | cut -d ':' -f 2)'"
	echo "Do not forget to remove $file in a production environment after storing it safely"
}

print_secret "registry"
print_secret "portainer"
