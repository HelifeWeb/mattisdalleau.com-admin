export $(cat .env) > /dev/null 2>&1 ;

mkdir -p "${HDCI_FOLDER}/traefik/letsencrypt"
mkdir -p "${HDCI_FOLDER}/traefik/logs"
mkdir -p "${HDCI_FOLDER}/drone/data"
mkdir -p "${HDCI_FOLDER}/registry"
mkdir -p "${HDCI_FOLDER}/portainer"
mkdir -p "${HDCI_FOLDER}/uptime-kuma"

docker stack deploy -c docker-compose.yml hdci
