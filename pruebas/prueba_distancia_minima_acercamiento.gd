# =============================================================================
# Prueba de AccionAtacar/AccionPerseguir._punto_de_acercamiento(): al
# acercarse a un objetivo, el punto comandado NUNCA es el centro exacto del
# objetivo — se queda a distancia_minima_acercamiento (pedido del usuario:
# "que lleguen a 20 o 25 pixeles, porque actualmente se colocan encima del
# jugador y casi no le da"). Antes, movimiento.comandar_destino() apuntaba
# directo a objetivo.global_position, así que el mob terminaba pegado al
# jugador y el golpe (que se coloca alcance_golpe px por DELANTE del propio
# mob) se pasaba de largo del radio de la habilidad casi siempre.
#
# Prueba la función pura directo, sin montar un árbol de comportamiento
# completo: no toca memoria ni estado del nodo, solo las posiciones que se
# le pasan — mismo criterio que el resto de las pruebas de este proyecto
# para no depender de un montaje completo cuando no hace falta.
#   godot --headless --path . --script res://pruebas/prueba_distancia_minima_acercamiento.gd
# =============================================================================
extends SceneTree

var _resultados: Array[bool] = []


func _process(_delta: float) -> bool:
	_probar_accion_atacar()
	_probar_accion_perseguir()
	_probar_respaldo_distancia_cero()
	return _informar()


## Carga el script SUELTO (no como tipo estático): AccionAtacar.gd depende
## de MovimientoComponente.gd, que a su vez referencia el autoload
## GestorNiveles — si esta prueba lo nombrara como tipo (AccionAtacar.new()
## directo), Godot compilaría esa cadena entera ANTES de que el autoload
## esté resuelto y reventaría con "Identifier not found: GestorNiveles" (ya
## probado). Mismo patrón que ya usa prueba_sacudida.gd para VidaComponente/
## MovimientoComponente sueltos.
func _accion_atacar_nueva():
	return (load("res://componentes/arbol_comportamiento/utilidades/acciones/AccionAtacar.gd") as GDScript).new()


func _accion_perseguir_nueva():
	return (load("res://componentes/arbol_comportamiento/utilidades/acciones/AccionPerseguir.gd") as GDScript).new()


func _probar_accion_atacar() -> void:
	var accion = _accion_atacar_nueva()
	var agente := Node2D.new()
	var objetivo := Node2D.new()
	objetivo.global_position = Vector2(100, 0)
	agente.global_position = Vector2(300, 0)  # a la derecha del objetivo.

	var punto: Vector2 = accion._punto_de_acercamiento(agente, objetivo)
	var distancia_minima: float = accion.distancia_minima_acercamiento
	var distancia_ok: bool = absf(punto.distance_to(objetivo.global_position) - distancia_minima) < 0.01
	var lado_ok: bool = punto.x > objetivo.global_position.x  # se queda del lado por el que venía.
	var ok: bool = distancia_ok and lado_ok
	_resultados.append(ok)
	print("AccionAtacar._punto_de_acercamiento a %.1fpx del objetivo, del lado correcto (esperado true): %s (punto=%s, dist=%.2f)" % [
		distancia_minima, ok, punto, punto.distance_to(objetivo.global_position)
	])


func _probar_accion_perseguir() -> void:
	var accion = _accion_perseguir_nueva()
	var agente := Node2D.new()
	var objetivo := Node2D.new()
	objetivo.global_position = Vector2.ZERO
	agente.global_position = Vector2(0, -200)  # arriba del objetivo.

	var punto: Vector2 = accion._punto_de_acercamiento(agente, objetivo)
	var distancia_minima: float = accion.distancia_minima_acercamiento
	var distancia_ok: bool = absf(punto.distance_to(objetivo.global_position) - distancia_minima) < 0.01
	var lado_ok: bool = punto.y < objetivo.global_position.y
	var ok: bool = distancia_ok and lado_ok
	_resultados.append(ok)
	print("AccionPerseguir._punto_de_acercamiento a %.1fpx del objetivo, del lado correcto (esperado true): %s (punto=%s, dist=%.2f)" % [
		distancia_minima, ok, punto, punto.distance_to(objetivo.global_position)
	])


## Si agente y objetivo terminaran en la MISMA posición (no debería pasar en
## combate real), el vector agente-objetivo es cero y from_angle() de un
## ángulo indefinido sería degenerado — mismo respaldo que ya usa
## _elegir_destino_reposicionamiento para el mismo problema.
func _probar_respaldo_distancia_cero() -> void:
	var accion = _accion_atacar_nueva()
	var agente := Node2D.new()
	var objetivo := Node2D.new()
	objetivo.global_position = Vector2(50, 50)
	agente.global_position = Vector2(50, 50)

	var punto: Vector2 = accion._punto_de_acercamiento(agente, objetivo)
	var distancia_minima: float = accion.distancia_minima_acercamiento
	var ok: bool = absf(punto.distance_to(objetivo.global_position) - distancia_minima) < 0.01
	_resultados.append(ok)
	print("Respaldo cuando agente y objetivo coinciden (esperado true): %s (punto=%s)" % [ok, punto])


func _informar() -> bool:
	var exito: bool = _resultados.size() == 3
	for r in _resultados:
		exito = exito and r
	print("PRUEBA DISTANCIA MINIMA ACERCAMIENTO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
