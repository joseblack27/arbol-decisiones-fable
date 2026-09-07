#!/usr/bin/env bash
# =============================================================================
# prueba_carga_remota.sh — como prueba_carga.sh pero SIN levantar un servidor
# local: lanza N bots (bot_carga.gd, uno por proceso Godot) contra un
# servidor YA desplegado en otro lado (una VM real de GCP, por ejemplo). Sirve
# para medir la capacidad de la MÁQUINA REAL bajo carga, no la del equipo del
# desarrollador — ver el checklist de pruebas de carga.
#
# El log "[CARGA] ..." vive en el servidor remoto, no acá: hay que mirarlo EN
# LA VM (docker compose logs -f servidor | grep CARGA) durante o después de
# esta corrida.
#
# Uso:
#   ./herramientas/carga/prueba_carga_remota.sh <ip> <cantidad_bots> [duracion_seg] [puerto] [espaciado_seg]
#
# Ejemplos:
#   ./herramientas/carga/prueba_carga_remota.sh 34.95.10.20 20            # 20 bots, 60s, puerto 8920, 150ms de espaciado
#   ./herramientas/carga/prueba_carga_remota.sh 34.95.10.20 50 180        # 50 bots, 180s
#   ./herramientas/carga/prueba_carga_remota.sh 34.95.10.20 10 60 8920 1  # espaciado de 1s (diagnóstico de ráfaga)
# =============================================================================
set -u

GODOT="${GODOT_BIN:-/d/Programas/Godot_v4.5.1/Godot_v4.5.1-stable_win64_console.exe}"
PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IP="${1:?Uso: prueba_carga_remota.sh <ip> <cantidad_bots> [duracion_seg] [puerto] [espaciado_seg]}"
CANTIDAD_BOTS="${2:?Uso: prueba_carga_remota.sh <ip> <cantidad_bots> [duracion_seg] [puerto] [espaciado_seg]}"
DURACION="${3:-60}"
PUERTO="${4:-8920}"
ESPACIADO="${5:-0.15}"
CARPETA_LOGS="$(mktemp -d)"

echo "== Prueba de carga REMOTA: $CANTIDAD_BOTS bots contra $IP:$PUERTO, ${DURACION}s =="
echo "Logs de los bots en: $CARPETA_LOGS"
echo "OJO: el log [CARGA] hay que mirarlo EN LA VM mientras esto corre."
echo ""

cd "$PROYECTO" || exit 1

# Escalonados (150ms entre cada uno): conectar todos de golpe no es realista
# y estresa el handshake de ENet artificialmente — mismo criterio que
# prueba_carga.sh.
PIDS_BOTS=()
for i in $(seq 1 "$CANTIDAD_BOTS"); do
	"$GODOT" --headless --path . --script res://herramientas/carga/bot_carga.gd \
		-- --id="$i" --duracion="$DURACION" --ip="$IP" --puerto="$PUERTO" \
		> "$CARPETA_LOGS/bot_$i.log" 2>&1 &
	PIDS_BOTS+=($!)
	sleep "$ESPACIADO"
done
echo "$CANTIDAD_BOTS bots lanzados. Esperando ${DURACION}s de sesión..."

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

CONECTADOS=$(grep -c "^BOT .*: spawneado" "$CARPETA_LOGS"/bot_*.log 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
ABANDONARON=$(grep -l "no logró spawnear" "$CARPETA_LOGS"/bot_*.log 2>/dev/null | wc -l)
echo ""
echo "== Bots que llegaron a spawnear: $CONECTADOS / $CANTIDAD_BOTS (abandonaron por timeout: $ABANDONARON) =="
echo "Logs completos de los bots: $CARPETA_LOGS"
echo "Andá a buscar la serie [CARGA] correspondiente a esta ventana en el log de la VM."
