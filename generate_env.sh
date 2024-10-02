#!/bin/sh -e

required_commands="openssl curl htpasswd jq base64"

for command in $required_commands; do
	if ! command -v $command > /dev/null; then
		echo "Missing required executable: $command" >&2
		exit 1
	fi
done

ask_yes_no() {
	while true; do
		read -p "$1 [y/n] " yn
		case $yn in
			[Yy]* ) return 0;;
			[Nn]* ) return 1;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}

PASSWORD_LENGTH=256

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

generate_secrets() {
	user="$(generate_secret)"
	pass="$(generate_secret)"
	rm -rf "$1"
	mkdir -p "$1"
	htpasswd -Bbc "$1/.htpasswd" "$user" "$pass"
	echo "$(echo $user:$pass | base64)" > "$1/.non-encrypted.b64"
}

if [ -z ${HDCI_FOLDER} ]; then
	echo "HDCI_FOLDER is not set"
	echo "Using default value: ./data/hdci"
	HDCI_FOLDER=./data/hdci
fi

HDCI_FOLDER_REGISTRY_AUTH="$HDCI_FOLDER/auth/registry"
HDCI_FOLDER_PORTAINER_AUTH="$HDCI_FOLDER/auth/portainer"

if [ $# -ne 7 ]; then
	echo "$0 <DOMAIN_NAME> <GITHUB_USER> <CLOUDFLARE_API_EMAIL> <CLOUDFLARE_API_KEY> <DRONE_GITHUB_CLIENT_ID> <DRONE_GITHUB_CLIENT_SECRET> <GITHUB_FILTERING>"
	echo "GITHUB_FILTERING can either be users or orgs separated by a comma"
	echo "If GITHUB_FILTERING is empty, all users and orgs will be allowed this is VERY DANGEROUS"
	exit 1
fi

cloudflare_trusted_ipv4=$(curl -s https://www.cloudflare.com/ips-v4 | tr '\n' ',')
cloudflare_trusted_ipv6=$(curl -s https://www.cloudflare.com/ips-v6 | tr '\n' ',')
cloudflare_trusted_ips="$cloudflare_trusted_ipv4,$cloudflare_trusted_ipv6"
cloudflare_trusted_ips=$(echo $cloudflare_trusted_ips | sed 's/,$//g' | sed 's/,,/,/g' | sed 's/\//\\\//g')

hdci_folder_sed_compliant=$(echo $HDCI_FOLDER | sed 's/\//\\\//g')

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
	sed "s/{{CLOUDFLARE_TRUSTED_IPS}}/$cloudflare_trusted_ips/g" | \
	sed "s/{{HDCI_FOLDER}}/$hdci_folder_sed_compliant/g" > .env

if should_generate_secrets "$HDCI_FOLDER_REGISTRY_AUTH"; then
	generate_secrets "$HDCI_FOLDER_REGISTRY_AUTH"
else
	echo "Skipping registry secrets generation for registry"
fi

if should_generate_secrets "$HDCI_FOLDER_PORTAINER_AUTH"; then
	generate_secrets "$HDCI_FOLDER_REGISTRY_AUTH"
else
	echo "Skipping registry secrets generation for portainer"
fi
