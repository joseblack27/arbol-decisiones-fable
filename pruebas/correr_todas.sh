#!/usr/bin/env bash
# =============================================================================
# Corre TODA la suite de pruebas (pruebas/prueba_*.gd) y resume al final.
#
#   ./pruebas/correr_todas.sh                     # usa el Godot por defecto
#   GODOT=/ruta/a/godot ./pruebas/correr_todas.sh # o uno específico
#   TRABAJOS=4 ./pruebas/correr_todas.sh          # cuántas pruebas a la vez
#
# En PARALELO (TRABAJOS a la vez, 6 por defecto): de a una tardaba 20-40 min.
# Cada prueba corre con su PROPIO user:// (APPDATA apuntando a una carpeta
# temporal, Godot lo respeta en Windows): así dos pruebas que guardan partida
# o configuración no se pisan entre sí, y ninguna escribe en el user:// real
# de esta PC (donde el cliente guarda IP, nombre y PIN).
#
# Una prueba que falla se REINTENTA una vez, sola: si pasa, se reporta como
# INESTABLE (no hace fallar la suite, pero queda a la vista) — hay fallas al
# azar conocidas del arnés ("Identifier not found: Utils" al compilar).
#
# IMPORTANTE: no usar --quit-after como tope global — varias pruebas de
# comportamiento (araña/lobo/ratón) simulan 16-20 s de juego (más de 1000
# fotogramas) y la de navegación necesita hornear el mapa completo; un tope
# de fotogramas las corta a mitad y reporta fallas falsas (pasó: un runner
# improvisado con --quit-after 600 "encontró" 4 fallas que no existían).
# Cada prueba termina sola con quit(0/1); el timeout de 150 s por prueba es
# solo la red de seguridad contra cuelgues reales.
# =============================================================================
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-/d/Programas/Godot_v4.5.1/Godot_v4.5.1-stable_win64_console.exe}"
TIMEOUT_S="${TIMEOUT_S:-150}"
TRABAJOS="${TRABAJOS:-6}"
CARPETA="$(mktemp -d)"

# Pruebas que necesitan rendering real (Vulkan) para tener sentido — chequean
# algo que se salta a propósito en DisplayServer "headless" (ver el propio
# comentario de cada una). Correrlas acá con --headless no las hace fallar
# por un bug real, sino porque nunca corre el código que están probando —
# repórtalas como fallas confundiría más de lo que ayuda. Se corren a mano:
#   "$GODOT" --path . --script res://pruebas/<nombre>.gd
PRUEBAS_SIN_HEADLESS=(
	"prueba_lanzallamas_visual_chorro"
	"prueba_lanzallamas_visual_remoto"
)

# Corre una prueba con su propio user:// y deja salida y código en $CARPETA.
correr_una() {
	local nombre="$1" sufijo="$2"
	local datos="$CARPETA/appdata/$nombre$sufijo"
	mkdir -p "$datos"
	APPDATA="$(cygpath -w "$datos" 2>/dev/null || echo "$datos")" \
		timeout "$TIMEOUT_S" "$GODOT" --headless --path . --script "res://pruebas/$nombre.gd" \
		> "$CARPETA/$nombre$sufijo.log" 2>&1
	echo $? > "$CARPETA/$nombre$sufijo.codigo"
}

# Criterio doble: quit(0) Y el "OK" impreso — exit 0 sin OK significa que la
# prueba terminó sin veredicto (cuelgue cortado por fuera).
paso() {
	local nombre="$1" sufijo="$2"
	[ "$(cat "$CARPETA/$nombre$sufijo.codigo")" -eq 0 ] && grep -q " OK" "$CARPETA/$nombre$sufijo.log"
}

pruebas=()
for f in pruebas/prueba_*.gd; do
	nombre=$(basename "$f" .gd)
	omitir=false
	for excluida in "${PRUEBAS_SIN_HEADLESS[@]}"; do
		[ "$nombre" = "$excluida" ] && omitir=true && break
	done
	if [ "$omitir" = true ]; then
		echo "OMITIDA $nombre (necesita rendering real, ver PRUEBAS_SIN_HEADLESS)"
		continue
	fi
	pruebas+=("$nombre")
done

inicio=$SECONDS
for nombre in "${pruebas[@]}"; do
	while [ "$(jobs -rp | wc -l)" -ge "$TRABAJOS" ]; do
		wait -n
	done
	correr_una "$nombre" "" &
done
wait

fallas=()
inestables=()
for nombre in "${pruebas[@]}"; do
	if paso "$nombre" ""; then
		echo "PASA  $nombre"
		continue
	fi
	correr_una "$nombre" ".reintento"
	if paso "$nombre" ".reintento"; then
		echo "PASA  $nombre (INESTABLE: falló la primera vez, pasó al reintentar)"
		inestables+=("$nombre")
	else
		echo "FALLA $nombre (exit=$(cat "$CARPETA/$nombre.reintento.codigo"))"
		grep -E "esperado true\): false|SCRIPT ERROR|Parse Error" "$CARPETA/$nombre.reintento.log" \
			| head -3 | sed 's/^/        /'
		fallas+=("$nombre")
	fi
done

total=${#pruebas[@]}
echo "================================================"
echo "Tiempo: $((SECONDS - inicio))s con $TRABAJOS pruebas a la vez"
if [ ${#inestables[@]} -gt 0 ]; then
	echo "Inestables (pasaron al reintentar): ${inestables[*]}"
fi
if [ ${#fallas[@]} -eq 0 ]; then
	echo "TODAS LAS PRUEBAS PASAN ($total de $total)"
	rm -rf "$CARPETA"
	exit 0
fi
echo "FALLARON ${#fallas[@]} de $total:"
printf '  - %s\n' "${fallas[@]}"
echo "Salidas completas en: $CARPETA"
exit 1
