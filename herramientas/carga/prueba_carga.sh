#!/usr/bin/env bash
# =============================================================================
# prueba_carga.sh — Fase 4 del plan de escalado a MMO: levanta el servidor
# dedicado real, conecta N bots (cada uno un proceso Godot separado, una
# conexión ENet físicamente distinta — no simulados dentro de un solo
# proceso) que se mueven y atacan, y al terminar imprime la serie temporal
# "[CARGA] ..." que el propio servidor fue logueando cada 5s
# (ver ServidorDedicado._reportar_capacidad).
#
# Uso:
#   ./herramientas/carga/prueba_carga.sh <cantidad_bots> [duracion_seg] [puerto]
#
# Ejemplos:
#   ./herramientas/carga/prueba_carga.sh 10          # 10 bots, 60s, puerto 8925
#   ./herramientas/carga/prueba_carga.sh 50 120       # 50 bots, 120s
#
# Usa un PUERTO APARTE (8925 por defecto) para no chocar con un servidor
# Docker que ya esté corriendo en 8920 — así se puede medir sin tocar la
# partida real.
# =============================================================================
set -u

GODOT="${GODOT_BIN:-/d/Programas/Godot_v4.5.1/Godot_v4.5.1-stable_win64_console.exe}"
PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CANTIDAD_BOTS="${1:?Uso: prueba_carga.sh <cantidad_bots> [duracion_seg] [puerto]}"
DURACION="${2:-60}"
PUERTO="${3:-8925}"
CARPETA_LOGS="$(mktemp -d)"

echo "== Prueba de carga: $CANTIDAD_BOTS bots, ${DURACION}s, puerto $PUERTO =="
echo "Logs en: $CARPETA_LOGS"

cd "$PROYECTO" || exit 1

# El puerto vive hardcodeado en Utils.PUERTO_JUEGO — se sustituye
# temporalmente y se restaura siempre al salir (incluso si algo falla a
# mitad de camino), para no dejar el proyecto con el puerto de prueba puesto.
# sed (no grep -P: falla por locale en Git Bash de Windows) extrae el dígito.
PUERTO_ORIGINAL=$(sed -n 's/^const PUERTO_JUEGO := \([0-9]*\)$/\1/p' autoloads/Utils.gd)
if [ -z "$PUERTO_ORIGINAL" ]; then
	echo "ERROR: no se pudo leer el puerto original de autoloads/Utils.gd — abortando SIN tocar nada."
	exit 1
fi
restaurar_puerto() {
	sed -i "s/const PUERTO_JUEGO := [0-9]*/const PUERTO_JUEGO := $PUERTO_ORIGINAL/" autoloads/Utils.gd
}
trap restaurar_puerto EXIT
sed -i "s/const PUERTO_JUEGO := [0-9]*/const PUERTO_JUEGO := $PUERTO/" autoloads/Utils.gd

# ── Servidor ──────────────────────────────────────────────────────────────
# Mismo comando exacto que docker/Dockerfile (CMD): la escena como argumento
# posicional, NO --script (--script espera un .gd que implemente SceneTree,
# no una .tscn — con --script acá los autoloads no llegan a cargar y todo
# revienta con "Identifier not found").
"$GODOT" --headless --path . res://escenas/mundo/ServidorDedicado.tscn \
	> "$CARPETA_LOGS/servidor.log" 2>&1 &
PID_SERVIDOR=$!
echo "Servidor arrancando (PID $PID_SERVIDOR)..."
sleep 5
if ! grep -q "escuchando" "$CARPETA_LOGS/servidor.log"; then
	echo "ERROR: el servidor no llegó a escuchar. Ver $CARPETA_LOGS/servidor.log"
	kill "$PID_SERVIDOR" 2>/dev/null
	exit 1
fi

# ── Bots ──────────────────────────────────────────────────────────────────
# Escalonados (150ms entre cada uno): conectar 100 a la vez de golpe no es
# realista (los jugadores reales entran goteando, no en un solo instante) y
# además estresaría el handshake de ENet artificialmente.
PIDS_BOTS=()
for i in $(seq 1 "$CANTIDAD_BOTS"); do
	"$GODOT" --headless --path . --script res://herramientas/carga/bot_carga.gd \
		-- --id="$i" --duracion="$DURACION" \
		> "$CARPETA_LOGS/bot_$i.log" 2>&1 &
	PIDS_BOTS+=($!)
	sleep 0.15
done
echo "$CANTIDAD_BOTS bots lanzados. Esperando ${DURACION}s de sesión..."

# ── Esperar a que los bots terminen solos (tienen su propio --duracion, más
# un margen de gracia para conectar/cargar nivel antes de que arranque) ───
# Cada bot tiene su propio timeout interno (_TIMEOUT_SPAWN=20s) para
# rendirse si nunca logra spawnear — pero por las dudas (bug futuro, o un
# proceso que cuelga por algo fuera de nuestro control), este es un tope
# DURO del lado del arnés: nunca vuelve a quedar esperando indefinidamente.
TOPE_TOTAL=$((DURACION + 60))
echo "(tope duro de esta espera: ${TOPE_TOTAL}s)"
TRANSCURRIDO=0
while [ "$TRANSCURRIDO" -lt "$TOPE_TOTAL" ]; do
	QUEDAN=0
	for pid in "${PIDS_BOTS[@]}"; do
		kill -0 "$pid" 2>/dev/null && QUEDAN=$((QUEDAN + 1))
	done
	[ "$QUEDAN" -eq 0 ] && break
	sleep 2
	TRANSCURRIDO=$((TRANSCURRIDO + 2))
done
for pid in "${PIDS_BOTS[@]}"; do
	if kill -0 "$pid" 2>/dev/null; then
		echo "AVISO: bot (PID $pid) no terminó dentro del tope — se lo mata a la fuerza."
		kill -9 "$pid" 2>/dev/null
	fi
done

# ── Resultados ────────────────────────────────────────────────────────────
CONECTADOS=$(grep -c "^BOT .*: spawneado" "$CARPETA_LOGS"/bot_*.log 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
ABANDONARON=$(grep -l "no logró spawnear" "$CARPETA_LOGS"/bot_*.log 2>/dev/null | wc -l)
echo ""
echo "== Bots que llegaron a spawnear: $CONECTADOS / $CANTIDAD_BOTS (abandonaron por timeout: $ABANDONARON) =="
echo ""
echo "== Serie temporal de capacidad del servidor =="
grep "^\[CARGA\]" "$CARPETA_LOGS/servidor.log"
echo ""
echo "Logs completos conservados en: $CARPETA_LOGS"

kill "$PID_SERVIDOR" 2>/dev/null
