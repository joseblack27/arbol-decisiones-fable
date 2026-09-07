# =============================================================================
# Prueba de PanelNotificacionesLoot:
#   1. Al emitir BusEventos.item_agregado, aparece una fila con el aviso.
#   2. Pedido explícito del usuario (2 sep 2026): "que no se vean 5 a la vez
#      sino uno a la vez, ya que siendo 5 ocupan demasiado espacio" — varios
#      ítems seguidos NO generan varias filas a la vez; solo una fila activa
#      (max_filas_visibles=1) y el resto espera en cola, mostrándose en orden
#      a medida que la fila activa termina su fundido (simulado acá emitiendo
#      "terminada" a mano, sin esperar la animación real).
#   3. La fila se recicla (pool): nunca se instancia una segunda fila mientras
#      la cola avanza, get_child_count() se mantiene en 1.
#   4. Pedido explícito del usuario: si hay más avisos detrás en la cola, la
#      fila activa dura poco (0.5s) para no atrasar al resto; la ÚLTIMA (o
#      la única, si no hay más) dura 3s para que se alcance a leer.
#   5. Toda la fila (y el panel) es no-interactuable: mouse_filter=IGNORE
#      en el contenedor raíz y en cada pieza de la fila.
#   6. Pedido explícito del usuario: achicar solo el ANCHO (170, antes 220)
#      sin tocar alto/ícono/fuente (32x32 / 14) — un ajuste anterior redujo
#      también el alto y el ícono salió deformado.
#   godot --headless --path . --script res://pruebas/prueba_notificaciones_loot.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _panel: Node
var _item: DatosItem
var _bus: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_bus.emit_signal("item_agregado", _item, 3)
			_bus.emit_signal("item_agregado", _item, 1)
			_bus.emit_signal("item_agregado", _item, 5)
		3:
			return _informar()
	return false


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_item = DatosItem.new()
	_item.name = "Poción"
	_item.type = 2

	_panel = (load("res://escenas/ui/notificaciones_loot/PanelNotificacionesLoot.tscn") as PackedScene).instantiate()
	root.add_child(_panel)


func _informar() -> bool:
	var una_fila_a_la_vez_ok: bool = _panel.get_child_count() == 1
	print("Solo 1 fila instanciada tras encolar 3 ítems (esperado 1): %d" % _panel.get_child_count())

	var fila: Node = _panel.get_child(0)
	var mouse_filter_panel: int = _panel.get("mouse_filter")
	var mouse_filter_fila: int = fila.get("mouse_filter")
	print("Panel no interactuable (mouse_filter=2 IGNORE): %d" % mouse_filter_panel)
	print("Fila no interactuable (mouse_filter=2 IGNORE): %d" % mouse_filter_fila)

	var texto_label: Label = fila.get_node("Margen/HBox/Texto")
	var primer_texto := texto_label.text
	var primera_duracion_ok: bool = fila.duracion_visible == 0.5
	print("Texto de la primera fila (esperado '+3 Poción'): %s" % primer_texto)
	print("Con 2 más en cola, dura 0.5s (esperado true): %s" % primera_duracion_ok)

	# Simula el fin del fundido de la fila activa (sin esperar la animación
	# real) para verificar que la cola avanza reciclando la MISMA fila, nunca
	# instanciando una segunda.
	fila.terminada.emit()
	var segundo_texto := texto_label.text
	var sigue_reciclando_ok: bool = _panel.get_child_count() == 1
	var segunda_duracion_ok: bool = fila.duracion_visible == 0.5
	print("Tras terminar la 1ra, sigue habiendo 1 sola fila (reciclada, esperado 1): %d" % _panel.get_child_count())
	print("Texto de la 2da fila en cola (esperado '+1 Poción'): %s" % segundo_texto)
	print("Con 1 más en cola, dura 0.5s (esperado true): %s" % segunda_duracion_ok)

	fila.terminada.emit()
	var tercer_texto := texto_label.text
	var tercera_duracion_ok: bool = fila.duracion_visible == 3.0
	print("Texto de la 3ra fila en cola (esperado '+5 Poción'): %s" % tercer_texto)
	print("Última en cola (nada más detrás), dura 3s (esperado true): %s" % tercera_duracion_ok)

	fila.terminada.emit()
	var cola_vacia_ok: bool = not fila.visible
	print("Sin más avisos en cola, la fila reciclada queda oculta (esperado true): %s" % cola_vacia_ok)

	# Único aviso en cola (nada detrás desde el arranque): también 3s.
	_bus.emit_signal("item_agregado", _item, 9)
	var duracion_unica_ok: bool = fila.duracion_visible == 3.0
	print("Único aviso en cola (nada detrás), dura 3s (esperado true): %s" % duracion_unica_ok)

	var ancho_reducido_solo_ok: bool = fila.custom_minimum_size == Vector2(170, 32) \
		and texto_label.get_theme_font_size("font_size") == 14 \
		and fila.get_node("Margen/HBox/Icono").custom_minimum_size == Vector2(32, 32)
	print("Solo el ancho se redujo (170x32, ícono 32x32 sin deformar, fuente 14) (esperado true): %s" % ancho_reducido_solo_ok)

	var exito := una_fila_a_la_vez_ok \
		and mouse_filter_panel == 2 \
		and mouse_filter_fila == 2 \
		and primer_texto == "+3 Poción" \
		and primera_duracion_ok \
		and sigue_reciclando_ok \
		and segundo_texto == "+1 Poción" \
		and segunda_duracion_ok \
		and tercer_texto == "+5 Poción" \
		and tercera_duracion_ok \
		and cola_vacia_ok \
		and duracion_unica_ok \
		and ancho_reducido_solo_ok
	print("PRUEBA NOTIFICACIONES LOOT %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
