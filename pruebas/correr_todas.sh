#!/usr/bin/env bash
# =============================================================================
# Corre TODA la suite de pruebas (pruebas/prueba_*.gd) y resume al final.
#
#   ./pruebas/correr_todas.sh                     # usa el Godot por defecto
#   GODOT=/ruta/a/godot ./pruebas/correr_todas.sh # o uno específico
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

total=0
fallas=()
for f in pruebas/prueba_*.gd; do
	nombre=$(basename "$f" .gd)
	total=$((total + 1))
	salida=$(timeout "$TIMEOUT_S" "$GODOT" --headless --path . --script "res://pruebas/$nombre.gd" 2>&1)
	codigo=$?
	# Criterio doble: quit(0) Y el "OK" impreso — exit 0 sin OK significa
	# que la prueba terminó sin veredicto (cuelgue cortado por fuera).
	if [ $codigo -eq 0 ] && printf '%s' "$salida" | grep -q " OK"; then
		echo "PASA  $nombre"
	else
		echo "FALLA $nombre (exit=$codigo)"
		fallas+=("$nombre")
	fi
done

echo "================================================"
if [ ${#fallas[@]} -eq 0 ]; then
	echo "TODAS LAS PRUEBAS PASAN ($total de $total)"
	exit 0
fi
echo "FALLARON ${#fallas[@]} de $total:"
printf '  - %s\n' "${fallas[@]}"
exit 1
