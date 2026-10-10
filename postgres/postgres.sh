#!/usr/bin/env bash
# Gestiona la base de datos PostgreSQL del proyecto (Docker Compose).
# Uso: ./postgres.sh <comando>   (ver ./postgres.sh help)
set -euo pipefail

POSTGRES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$POSTGRES_DIR/docker-compose.postgres.yaml"

info()  { echo -e "\033[1;34m[postgres]\033[0m $*"; }
error() { echo -e "\033[1;31m[postgres]\033[0m $*" >&2; }

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

check_docker() {
  if ! docker info >/dev/null 2>&1; then
    error "Docker no está disponible. Abre Docker Desktop y activa la integración con WSL."
    exit 1
  fi
}

cmd_start() {
  compose up -d --wait
  info "Base de datos lista en localhost:5432 (base, usuario y clave: mailamericas)"
}

cmd_stop() {
  compose stop
  info "Base de datos detenida (los datos se conservan)."
}

cmd_restart() {
  info "Reiniciando la base de datos..."
  compose stop
  cmd_start
}

usage() {
  cat <<USAGE
Uso: ./postgres.sh <comando>

  start      Levanta la base de datos
  stop       Apaga la base de datos sin borrar los datos
  restart    Reinicia la base de datos (conserva los datos)
  status     Muestra el estado del contenedor
USAGE
}

COMMAND="${1:-help}"

case "$COMMAND" in
  help|-h|--help) usage; exit 0 ;;
esac

check_docker

case "$COMMAND" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_restart ;;
  status)  compose ps -a ;;
  *)       error "Comando desconocido: $COMMAND"; usage; exit 1 ;;
esac
