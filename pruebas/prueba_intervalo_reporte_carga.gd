# =============================================================================
# El reporte "[CARGA]" del servidor dedicado se controla con la variable de
# entorno CARGA_INTERVALO (ver ServidorDedicado.intervalo_reporte_desde), para
# prenderlo, apagarlo o espaciarlo desde el docker-compose sin reconstruir la
# imagen.
#
# Confirma:
#   1. Sin la variable (vacía) se reporta cada 5 s, como siempre.
#   2. "0" o un negativo lo apagan.
#   3. Un número (con espacios alrededor, o decimal) se respeta.
#   4. Algo que no es un número cae al valor por defecto: un typo no debe
#      apagar la medición.
#   godot --headless --path . --script res://pruebas/prueba_intervalo_reporte_carga.gd
# =============================================================================
extends SceneTree

var _exito := true


func _process(_d: float) -> bool:
	# Solo el script, sin instanciar la escena: su _ready() abriría el puerto.
	var servidor: GDScript = load("res://escenas/mundo/ServidorDedicado.gd")
	_verificar("Sin variable: cada 5 s", servidor.intervalo_reporte_desde("") == 5.0)
	_verificar("Solo espacios: cada 5 s", servidor.intervalo_reporte_desde("   ") == 5.0)
	_verificar("\"0\" lo apaga", servidor.intervalo_reporte_desde("0") == 0.0)
	_verificar("Negativo lo apaga", servidor.intervalo_reporte_desde("-3") == 0.0)
	_verificar("\"10\" = 10 s", servidor.intervalo_reporte_desde("10") == 10.0)
	_verificar("\" 2.5 \" = 2.5 s", servidor.intervalo_reporte_desde(" 2.5 ") == 2.5)
	_verificar("Texto cualquiera: cada 5 s", servidor.intervalo_reporte_desde("cinco") == 5.0)
	print("PRUEBA INTERVALO REPORTE CARGA %s" % ("OK" if _exito else "FALLIDA"))
	quit(0 if _exito else 1)
	return true


func _verificar(texto: String, ok: bool) -> void:
	_exito = _exito and ok
	print("%s (esperado true): %s" % [texto, ok])
