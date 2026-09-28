#!/usr/bin/env bash
# =============================================================================
# verificar_red.sh — prueba el camino REAL del juego (servidor dedicado +
# cliente conectado por ENet) antes de deployar. Las pruebas de pruebas/ corren
# casi todas SIN red, un camino que el juego real nunca usa (Mundo.gd siempre
# se conecta a un servidor); esto cubre lo que ellas no ven.
#
# Levanta un servidor dedicado local en un puerto aparte y corre, uno por uno,
# los bots de verificación contra él:
#   - bot_movimiento_red.gd: empuja y suelta el joystick real; el servidor
#     tiene que moverlo y frenarlo sin deriva (también con el input cortado).
#   - bot_replicacion_enemigos.gd: altas/bajas de mobs; la reconciliación
#     periódica no tiene que corregir nada tras la primera.
#
# Uso:
#   ./herramientas/carga/verificar_red.sh [puerto]
#   GODOT=/ruta/a/godot ./herramientas/carga/verificar_red.sh
#
# Puerto 8926 por defecto, para no chocar con un servidor Docker en 8920 ni
# con prueba_carga.sh (8925). Como el servidor lee el puerto de
# Utils.PUERTO_JUEGO, se sustituye ahí mientras dura y se restaura SIEMPRE al
# salir (mismo criterio que prueba_carga.sh).
# Sale con código 0 solo si todos los bots dan OK.
# =============================================================================
set -u

GODOT="${GODOT:-/d/Programas/Godot_v4.5.1/Godot_v4.5.1-stable_win64_console.exe}"
PROYECTO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PUERTO="${1:-8926}"
CARPETA_LOGS="$(mktemp -d)"
TOPE_POR_BOT=150

cd "$PROYECTO" || exit 1

PUERTO_ORIGINAL=$(sed -n 's/^const PUERTO_JUEGO := \([0-9]*\)$/\1/p' autoloads/Utils.gd)
if [ -z "$PUERTO_ORIGINAL" ]; then
	echo "ERROR: no se pudo leer el puerto de autoloads/Utils.gd — abortando SIN tocar nada."
	exit 1
fi

PID_SERVIDOR=""
limpiar() {
	[ -n "$PID_SERVIDOR" ] && kill "$PID_SERVIDOR" 2>/dev/null
	sed -i "s/const PUERTO_JUEGO := [0-9]*/const PUERTO_JUEGO := $PUERTO_ORIGINAL/" autoloads/Utils.gd
}
trap limpiar EXIT
sed -i "s/const PUERTO_JUEGO := [0-9]*/const PUERTO_JUEGO := $PUERTO/" autoloads/Utils.gd

echo "== Verificación de red: servidor local en el puerto $PUERTO =="
echo "Logs en: $CARPETA_LOGS"

"$GODOT" --headless --path . res://escenas/mundo/ServidorDedicado.tscn \
	> "$CARPETA_LOGS/servidor.log" 2>&1 &
PID_SERVIDOR=$!
for _ in $(seq 1 30); do
	grep -q "escuchando" "$CARPETA_LOGS/servidor.log" 2>/dev/null && break
	sleep 1
done
if ! grep -q "escuchando" "$CARPETA_LOGS/servidor.log"; then
	echo "ERROR: el servidor no llegó a escuchar. Ver $CARPETA_LOGS/servidor.log"
	exit 1
fi

FALLARON=()
correr_bot() {
	local nombre="$1"
	shift
	echo ""
	echo "-- $nombre --"
	timeout "$TOPE_POR_BOT" "$GODOT" --headless --path . \
		--script "res://herramientas/carga/$nombre.gd" -- --puerto="$PUERTO" "$@" \
		> "$CARPETA_LOGS/$nombre.log" 2>&1
	local codigo=$?
	grep -E "^\[BOT-" "$CARPETA_LOGS/$nombre.log"
	if [ "$codigo" -ne 0 ]; then
		[ "$codigo" -eq 124 ] && echo "(se cortó al superar ${TOPE_POR_BOT}s)"
		FALLARON+=("$nombre")
	fi
}

correr_bot bot_movimiento_red
correr_bot bot_replicacion_enemigos --duracion=50

ERRORES_SERVIDOR=$(grep -c "SCRIPT ERROR" "$CARPETA_LOGS/servidor.log")
echo ""
echo "== Errores de script en el servidor: $ERRORES_SERVIDOR =="
if [ "$ERRORES_SERVIDOR" -gt 0 ]; then
	grep "SCRIPT ERROR" "$CARPETA_LOGS/servidor.log" | sort | uniq -c | sort -rn | head -10
	FALLARON+=("servidor (errores de script)")
fi

echo ""
if [ ${#FALLARON[@]} -eq 0 ]; then
	echo "== VERIFICACIÓN DE RED OK =="
	exit 0
fi
echo "== VERIFICACIÓN DE RED FALLIDA: ${FALLARON[*]} =="
echo "Logs completos en: $CARPETA_LOGS"
exit 1
