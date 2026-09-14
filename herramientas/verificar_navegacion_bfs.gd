# =============================================================================
# herramientas/verificar_navegacion_bfs.gd — confirma que la malla de
# Navegacion de un nivel sea de verdad UNA sola región conectada (o reporta
# qué celdas quedaron aisladas) antes de colocar spawners/jefes/compuertas
# encima. Reemplaza al script de introspección "BFS + mapa ascii" que
# verificó las 3 ramas de la Mina a mano y nunca quedó persistido en el
# repo — esta vez queda como herramienta reusable para cualquier nivel con
# capa Navegacion por celda (no aplica a NivelCamino, que usa un único
# NavigationRegion2D en vez de tiles).
#
# Editar RUTA_NIVEL/CELDA_ORIGEN abajo antes de cada corrida (mismo criterio
# que las listas hardcodeadas de generar_capa_navegacion.gd).
#   godot --headless --path . --script res://herramientas/verificar_navegacion_bfs.gd
# =============================================================================
extends SceneTree

const RUTA_NIVEL := "res://escenas/niveles/NivelHormiguero.tscn"
## Celda de Navegacion (no de Terreno) desde la que arranca la exploración —
## normalmente la celda bajo PuntoAparicion. Ajustar antes de correr.
const CELDA_ORIGEN := Vector2i(-100, -20)
## Radio del mapa ascii impreso alrededor del origen, en celdas de Navegacion.
const RADIO_ASCII := 30


func _initialize() -> void:
	var nivel := (load(RUTA_NIVEL) as PackedScene).instantiate()
	var navegacion := nivel.get_node_or_null("Navegacion") as TileMapLayer
	if navegacion == null:
		push_error("%s: no tiene nodo Navegacion." % RUTA_NIVEL)
		quit(1)
		return

	var pintadas := {}
	for celda in navegacion.get_used_cells():
		pintadas[celda] = true

	var alcanzables := _explorar_alcanzables(pintadas, CELDA_ORIGEN)

	print("Navegacion de %s: %d celdas pintadas, %d alcanzables desde %s." % [
		RUTA_NIVEL, pintadas.size(), alcanzables.size(), CELDA_ORIGEN])

	if alcanzables.is_empty():
		print("ERROR: el origen %s no está pintado en Navegacion (o no tiene vecinos) -- nada es alcanzable." % CELDA_ORIGEN)
	elif alcanzables.size() < pintadas.size():
		print("ATENCION: %d celdas pintadas NO son alcanzables desde el origen (islas sueltas):" % (pintadas.size() - alcanzables.size()))
		var listadas := 0
		for celda in pintadas:
			if not alcanzables.has(celda):
				print("  - %s" % celda)
				listadas += 1
				if listadas >= 40:
					print("  ... (%d más, no se listan todas)" % (pintadas.size() - alcanzables.size() - listadas))
					break
	else:
		print("OK: toda la malla pintada está conectada en una sola región.")

	_imprimir_ascii(pintadas, alcanzables, CELDA_ORIGEN)

	nivel.free()
	quit(0)


## BFS real con cursor por índice (no pop_front/pop_back): con miles de
## celdas, popear del frente de un Array es O(n) por elemento -- un cursor
## que solo avanza mantiene cada celda en O(1) amortizado.
func _explorar_alcanzables(pintadas: Dictionary, origen: Vector2i) -> Dictionary:
	var visitados := {}
	if not pintadas.has(origen):
		push_warning("La celda de origen %s no está pintada en Navegacion." % origen)
		return visitados
	var cola: Array[Vector2i] = [origen]
	visitados[origen] = true
	var direcciones: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var indice := 0
	while indice < cola.size():
		var actual: Vector2i = cola[indice]
		indice += 1
		for d in direcciones:
			var vecino := actual + d
			if pintadas.has(vecino) and not visitados.has(vecino):
				visitados[vecino] = true
				cola.append(vecino)
	return visitados


func _imprimir_ascii(pintadas: Dictionary, alcanzables: Dictionary, centro: Vector2i) -> void:
	print("Mapa ascii alrededor de %s ('.'=alcanzable, 'X'=aislado, 'o'=origen, ' '=sin pintar):" % centro)
	for y in range(centro.y - RADIO_ASCII, centro.y + RADIO_ASCII + 1):
		var fila := ""
		for x in range(centro.x - RADIO_ASCII, centro.x + RADIO_ASCII + 1):
			var celda := Vector2i(x, y)
			if celda == centro:
				fila += "o"
			elif not pintadas.has(celda):
				fila += " "
			elif alcanzables.has(celda):
				fila += "."
			else:
				fila += "X"
		print(fila)
