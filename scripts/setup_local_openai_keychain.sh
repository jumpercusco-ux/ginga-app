#!/usr/bin/env bash
set -euo pipefail

# Registro seguro y único de la API Key local de OpenAI en macOS Keychain.
# - Entrada 100% oculta (read -r -s + security -i -X hex por stdin, sin límite de 128 chars de getpass()).
# - Cero almacenamiento en archivos (.env, .zshrc, código o Git) y cero exposición en argumentos CLI (`ps`).
# - No realiza llamadas a OpenAI ni altera Firebase Secret Manager / producción.

SERVICE_NAME="ginga-dev-openai-api-key"
ACCOUNT_NAME="${USER:-ginga_dev}"
KEY_LABEL="GINGA Dev OpenAI API Key"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: Este script requiere macOS (macOS Keychain)." >&2
  exit 1
fi

for cmd in security xxd; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: No se encontró la utilidad requerida del sistema '$cmd'." >&2
    exit 1
  fi
done

case "${1:-}" in
  --check)
    STORED_VAL="$(security find-generic-password -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" -w 2>/dev/null || true)"
    if [[ -n "${STORED_VAL// /}" ]]; then
      STORED_LEN="${#STORED_VAL}"
      unset STORED_VAL
      echo "OK: Clave registrada en macOS Keychain (servicio: '$SERVICE_NAME', cuenta: '$ACCOUNT_NAME', longitud: $STORED_LEN caracteres)."
      if [[ "$STORED_LEN" -eq 128 ]]; then
        echo "Aviso: La longitud exacta de 128 caracteres puede deberse a truncamiento previo; ejecuta ./scripts/setup_local_openai_keychain.sh para actualizarla." >&2
      fi
      exit 0
    fi
    unset STORED_VAL
    echo "Falta registrar la clave en macOS Keychain (servicio: '$SERVICE_NAME')." >&2
    exit 1
    ;;
  --delete)
    if security delete-generic-password -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" >/dev/null 2>&1; then
      echo "Clave eliminada de macOS Keychain (servicio: '$SERVICE_NAME')."
      exit 0
    fi
    echo "No existía una clave registrada para '$SERVICE_NAME'."
    exit 0
    ;;
  --help|-h)
    cat <<EOF
Uso: ./scripts/setup_local_openai_keychain.sh [--check | --delete | --help]

Registra o actualiza de forma oculta y permanente la API Key local de OpenAI
en macOS Keychain (servicio '$SERVICE_NAME', cuenta '$ACCOUNT_NAME'), soportando
claves de más de 128 caracteres (ej. claves sk-proj-...) sin truncamiento.
EOF
    exit 0
    ;;
esac

RAW_KEY=""
CLEAN_KEY=""
KEY_HEX=""
VERIFY_VAL=""
cleanup() {
  unset RAW_KEY CLEAN_KEY KEY_HEX VERIFY_VAL
}
trap cleanup EXIT

echo "=== Registro seguro en macOS Keychain (GINGA Desarrollo Local) ==="
echo "Servicio : $SERVICE_NAME"
echo "Cuenta   : $ACCOUNT_NAME"
echo ""
echo "Pega tu API Key completa y presiona Enter (entrada oculta, sin límite de 128 caracteres)."
echo ""

IFS= read -r -s -p "API Key OpenAI: " RAW_KEY
printf '\n'

CLEAN_KEY="$(printf '%s' "$RAW_KEY" | tr -d '\r\n\t ')"
RAW_KEY=""

if [[ -z "$CLEAN_KEY" ]]; then
  echo "Error: No ingresaste ninguna clave." >&2
  exit 1
fi

EXPECTED_LEN="${#CLEAN_KEY}"
KEY_HEX="$(printf '%s' "$CLEAN_KEY" | xxd -p | tr -d '\n')"

security -i >/dev/null <<EOF
add-generic-password -U -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" -l "$KEY_LABEL" -T "/usr/bin/security" -X "$KEY_HEX"
EOF

VERIFY_VAL="$(security find-generic-password -a "$ACCOUNT_NAME" -s "$SERVICE_NAME" -w 2>/dev/null || true)"
ACTUAL_LEN="${#VERIFY_VAL}"

if [[ -z "${VERIFY_VAL// /}" || "$ACTUAL_LEN" -ne "$EXPECTED_LEN" ]]; then
  echo "Error: La clave almacenada no coincide en longitud (esperada: $EXPECTED_LEN, leída: $ACTUAL_LEN)." >&2
  exit 1
fi

echo ""
echo "Listo: clave completa almacenada y verificada en macOS Keychain (longitud verificada: $ACTUAL_LEN caracteres; contenido nunca expuesto)."
if [[ "$ACTUAL_LEN" -lt 40 ]]; then
  echo "Aviso: La longitud parece menor a una clave estándar de OpenAI; verifica si la copiaste completa." >&2
fi
echo "Ahora puedes iniciar el servidor local con: ./scripts/start_ginga_dev_server.sh"
