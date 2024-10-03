#!/bin/bash

set -e

required_commands="openssl curl htpasswd base64"

for command in $required_commands; do
	if ! command -v $command > /dev/null; then
		echo "Missing required executable: $command" >&2
		exit 1
	fi
done

ask_yes_no() {
	while true; do
		read -p "$1 [y/N] " yn
		case $yn in
			[Yy]* ) return 0;;
			[Nn]* ) return 1;;
			* ) echo "Defaulting to no."; return 0 ;;
		esac
	done
}

PASSWORD_LENGTH=64

generate_secret() {
	current=$PASSWORD_LENGTH
	if [ ! -z "$1" ]; then
		current=$1
	fi
	openssl rand -hex $current
}

should_generate_secrets() {
	if [ -f "$1/.htpasswd" ]; then
		ask_yes_no "Secrets for '$1' already exist. Do you want to generate them again?"
		return $?
	fi
	return 0
}

make_auth_services() {
	local var="$1"
	for service in "${var[@]}" ; do
		local service_path="$HDCI_STATIC_CONFIGURATION/$2/$service"

		if should_generate_secrets "$service_path"; then
			generate_secrets "$service_path"
		else
			echo "Skipping secrets generation for $service"
		fi
	done
}

generate_secrets() {
	user="$(generate_secret)"
	pass="$(generate_secret)"
	rm -rf "$1"
	mkdir -p "$1"
	htpasswd -Bbc "$1/.htpasswd" "$user" "$pass"
	echo "$(echo $user:$pass | base64)" > "$1/.non-encrypted.b64"
}

get_cloudflare_trusted_ips() {
	local cloudflare_trusted_ipv4=$(curl -s https://www.cloudflare.com/ips-v4 | tr '\n' ',')
	local cloudflare_trusted_ipv6=$(curl -s https://www.cloudflare.com/ips-v6 | tr '\n' ',')
	local cloudflare_trusted_ips="$cloudflare_trusted_ipv4,$cloudflare_trusted_ipv6"
	local cloudflare_trusted_ips=$(echo $cloudflare_trusted_ips | sed 's/,$//g' | sed 's/,,/,/g' | sed 's/\//\\\//g')
	echo -ne "$cloudflare_trusted_ips"
}

if [ $# -ne 7 ]; then
	echo "$0 <DOMAIN_NAME> <GITHUB_USER> <CLOUDFLARE_API_EMAIL> <CLOUDFLARE_API_KEY> <DRONE_GITHUB_CLIENT_ID> <DRONE_GITHUB_CLIENT_SECRET> <GITHUB_FILTERING>"
	echo "GITHUB_FILTERING can either be users or orgs separated by a comma"
	echo "If GITHUB_FILTERING is empty, all users and orgs will be allowed this is VERY DANGEROUS"
	exit 1
fi

if [ -z "${HDCI_FOLDER}" ]; then
	echo "HDCI_FOLDER is not set"
	echo "Using default value: ./docker-data/hdci"
	HDCI_FOLDER=./docker-data/hdci
fi

HDCI_STATIC_CONFIGURATION="$HDCI_FOLDER/static-configurations"

# Ensure most of the base folders
mkdir -p "$HDCI_STATIC_CONFIGURATION"

hdci_folder_sed_compliant=$(echo $HDCI_FOLDER | sed 's/\//\\\//g')

cp -ri static-configurations/ "$HDCI_FOLDER"

cat .env.example | \
	sed "s/{{DOMAIN}}/$1/g" | \
	sed "s/{{GITHUB_USER}}/$2/g" | \
	sed "s/{{CLOUDFLARE_API_EMAIL}}/$3/g" | \
	sed "s/{{CLOUDFLARE_API_KEY}}/$4/g" | \
	sed "s/{{DRONE_GITHUB_CLIENT_ID}}/$5/g" | \
	sed "s/{{DRONE_GITHUB_CLIENT_SECRET}}/$6/g" | \
	sed "s/{{DRONE_RPC_SECRET}}/$(generate_secret 32)/g" | \
	sed "s/{{GITHUB_FILTERING}}/$7/g" | \
	sed "s/{{DRONE_DATABASE_SECRET}}/$(generate_secret 32)/g" | \
	sed "s/{{HDCI_FOLDER}}/$hdci_folder_sed_compliant/g" > .env

sed -i "s/{{CLOUDFLARE_TRUSTED_IPS}}/$(get_cloudflare_trusted_ips)/g" \
	"$HDCI_FOLDER/static-configurations/traefik/conf.yaml"

private_auth=("registry")
rev_proxy_auth=("portainer")

make_auth_services "$rev_proxy_auth" "auth/rev-proxy"
make_auth_services "$private_auth" "auth/private"
