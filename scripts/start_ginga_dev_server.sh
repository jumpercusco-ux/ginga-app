#!/usr/bin/env bash
set -euo pipefail

# Arranque sencillo del servidor local aislado de GINGA con recuperación automática
# desde macOS Keychain en memoria (cero archivos planos, cero cambios a presupuestos).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SERVICE_NAME="ginga-dev-openai-api-key"
ACCOUNT_NAME="${USER:-ginga_dev}"
DEFAULT_STATIC_DIR="/tmp/ginga_ped04c2d_8097"

MODE="copilot"
HOST="127.0.0.1"
PORT="8097"
MODEL="gpt-4o-mini"
STATIC_DIR_SET=0
EXTRA_ARGS=()

show_help() {
  cat <<EOF
Uso: ./scripts/start_ginga_dev_server.sh [MODO] [OPCIONES]

Modos:
  --copilot     (por defecto) Habilita OpenAI real solo para Copiloto (gpt-4o-mini, tope \$0.05, 6 turnos)
  --generator   Habilita OpenAI real solo para Generador de Clases V2 (gpt-4o-mini, tope \$0.10, max 8)
  --all         Habilita OpenAI real para Copiloto y Generador preservando sus presupuestos separados
  --offline     Inicia en modo simulado 100% offline (no consulta Keychain ni OpenAI)

Opciones útiles:
  --port <N>                    Puerto HTTP local (por defecto: 8097)
  --host <IP>                   Host de enlace (por defecto: 127.0.0.1)
  --static-dir <DIR>            Carpeta Flutter Web compilada (por defecto: /tmp/ginga_ped04c2d_8097)
  --model <ID>                  Modelo OpenAI (por defecto: gpt-4o-mini)
  --copilot-budget-usd <USD>    Tope USD del copiloto (por defecto: 0.05)
  --copilot-max-generations <N> Turnos máximos del copiloto (por defecto: 6)
  --budget-usd <USD>            Tope USD del generador (por defecto: 0.10)
  --max-real-generations <N>    Generaciones máximas del generador (por defecto: 8)
  --token <PIN>                 Requerido si --host no es loopback
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copilot)
      MODE="copilot"
      shift
      ;;
    --generator)
      MODE="generator"
      shift
      ;;
    --all)
      MODE="all"
      shift
      ;;
    --offline)
      MODE="offline"
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --static-dir|--web-dir)
      STATIC_DIR_SET=1
      EXTRA_ARGS+=("--static-dir" "$2")
      shift 2
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

SERVER_ARGS=(
  "scripts/planner_v2_local_server.js"
  "--host" "$HOST"
  "--port" "$PORT"
)

if [[ "$STATIC_DIR_SET" -eq 0 && -d "$DEFAULT_STATIC_DIR" ]]; then
  SERVER_ARGS+=("--static-dir" "$DEFAULT_STATIC_DIR")
fi

case "$MODE" in
  offline)
    ;;
  copilot)
    SERVER_ARGS+=(
      "--enable-real-copilot-openai"
      "--model" "$MODEL"
      "--copilot-budget-usd" "0.05"
      "--copilot-max-generations" "6"
    )
    ;;
  generator)
    SERVER_ARGS+=(
      "--enable-real-openai"
      "--model" "$MODEL"
      "--budget-usd" "0.10"
      "--max-real-generations" "8"
    )
    ;;
  all)
    SERVER_ARGS+=(
      "--enable-real-openai"
      "--enable-real-copilot-openai"
      "--model" "$MODEL"
      "--budget-usd" "0.10"
      "--max-real-generations" "8"
      "--copilot-budget-usd" "0.05"
      "--copilot-max-generations" "6"
    )
    ;;
esac

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  SERVER_ARGS+=("${EXTRA_ARGS[@]}")
fi

if [[ "$MODE" == "offline" ]]; then
  exec node "${SERVER_ARGS[@]}"
fi

RESOLVED_KEY="${PLANNER_V2_OPENAI_API_KEY:-${OPENAI_API_KEY:-}}"
if [[ -z "${RESOLVED_KEY// /}" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]] && command -v security >/dev/null 2>&1; then
    RESOLVED_KEY="$(security find-generic-password -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" -w 2>/dev/null || true)"
  fi
fi

if [[ -z "${RESOLVED_KEY// /}" ]]; then
  echo "Error: No se encontró la API Key en variables de entorno ni en macOS Keychain ('$SERVICE_NAME')." >&2
  echo "Regístrala una sola vez con entrada oculta ejecutando:" >&2
  echo "  ./scripts/setup_local_openai_keychain.sh" >&2
  exit 1
fi

echo "Clave recuperada en memoria de forma segura (sin exposición en logs ni disco). Iniciando servidor ($MODE)..."
OPENAI_API_KEY="$RESOLVED_KEY" exec node "${SERVER_ARGS[@]}"
