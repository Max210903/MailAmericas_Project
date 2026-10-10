#!/usr/bin/env bash
# Gestiona el ambiente local de Apache Airflow (Docker Compose + WSL).
# Uso: ./airflow.sh <comando>   (ver ./airflow.sh help)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$PROJECT_DIR/docker_configuration"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.airflow.yaml"
ENV_FILE="$DOCKER_DIR/.env"
WEB_URL="http://localhost:8080"

info()  { echo -e "\033[1;34m[airflow]\033[0m $*"; }
error() { echo -e "\033[1;31m[airflow]\033[0m $*" >&2; }

compose() {
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}

check_docker() {
  if ! docker info >/dev/null 2>&1; then
    error "Docker no está disponible. Abre Docker Desktop y activa la integración con WSL."
    exit 1
  fi
}

# Crea las carpetas montadas y el .env (está en .gitignore, así que no viene con el repo).
prepare() {
  mkdir -p "$PROJECT_DIR"/{dags,logs,plugins,config}
  if [[ ! -f "$ENV_FILE" ]]; then
    info "Creando $ENV_FILE"
    printf 'AIRFLOW_UID=%s\nAIRFLOW_PROJ_DIR=..\n' "$(id -u)" > "$ENV_FILE"
  fi
}

wait_for_webserver() {
  info "Esperando a que el webserver responda..."
  for _ in $(seq 1 60); do
    if curl -fsS "$WEB_URL/health" >/dev/null 2>&1; then
      info "Airflow listo en $WEB_URL (usuario: airflow / clave: airflow)"
      return 0
    fi
    sleep 5
  done
  error "El webserver no respondió a tiempo. Revisa: ./airflow.sh logs airflow-webserver"
  return 1
}

confirm() {
  [[ "${ASSUME_YES:-false}" == "true" ]] && return 0
  read -r -p "$1 [s/N] " answer
  [[ "$answer" =~ ^[sSyY]$ ]]
}

cmd_init() {
  prepare
  info "Construyendo la imagen..."
  compose build
  info "Migrando la base de datos y creando el usuario admin..."
  compose up airflow-init
  info "Levantando los servicios..."
  compose up -d
  wait_for_webserver
}

cmd_start() {
  prepare
  compose up -d
  wait_for_webserver
}

cmd_stop() {
  compose stop
}

cmd_restart() {
  prepare
  info "Reiniciando los servicios..."
  compose down
  compose up -d
  wait_for_webserver
}

cmd_destroy() {
  confirm "Esto elimina contenedores, la base de datos de Airflow, la imagen y los logs. ¿Continuar?" \
    || { info "Cancelado."; exit 0; }
  prepare
  compose down --volumes --remove-orphans --rmi local
  rm -rf "${PROJECT_DIR:?}/logs"/*
  info "Ambiente eliminado (dags/, plugins/ y config/ se conservan)."
}

cmd_reset() {
  cmd_destroy
  cmd_init
}

usage() {
  cat <<EOF
Uso: ./airflow.sh <comando> [-y]

  init       Inicializa el ambiente: construye la imagen, migra la BD y levanta todo
  start      Levanta los servicios ya inicializados
  stop       Detiene los servicios sin borrar nada
  restart    Reinicia los servicios (conserva la BD)
  reset      Elimina todo y vuelve a inicializar desde cero
  destroy    Elimina contenedores, volúmenes (BD), imagen y logs
  status     Muestra el estado de los contenedores
  logs [svc] Sigue los logs (opcionalmente de un servicio)

  -y         No pide confirmación en reset/destroy
EOF
}

COMMAND="${1:-help}"
shift || true

ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "-y" ]]; then ASSUME_YES=true; else ARGS+=("$arg"); fi
done

case "$COMMAND" in
  help|-h|--help) usage; exit 0 ;;
esac

check_docker

case "$COMMAND" in
  init)    cmd_init ;;
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_restart ;;
  reset)   cmd_reset ;;
  destroy) cmd_destroy ;;
  status)  prepare; compose ps ;;
  logs)    prepare; compose logs -f --tail=100 "${ARGS[@]}" ;;
  *)       error "Comando desconocido: $COMMAND"; usage; exit 1 ;;
esac
