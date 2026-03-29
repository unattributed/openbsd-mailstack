#!/bin/sh
set -eu

DIR="${1:-.}"
PORT="${2:-8000}"

echo "Serving ${DIR} on http://0.0.0.0:${PORT}/"
echo "Ensure your installer can reach the selected host IP and that the generated install.conf points to the correct HTTP host."
exec python3 -m http.server "${PORT}" --directory "${DIR}"
