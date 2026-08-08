# =============================================================================
# Prueba de PanelDetallePasiva mostrando SOLO los efectos (sin texto de
# descripción) para una pasiva de ESTADÍSTICA — pedido del usuario:
# "no quiero descripcion, solo ver los efectos": "Efectos actuales:" con el
# bono de HOY y, más abajo, "Efectos en el siguiente nivel:" — oculto al
# llegar al tope. Cada efecto lleva su propio cuadrito de color (ver
# PanelDetallePasiva._llenar_lista_efectos) — pedido del usuario: un ícono
# por estadística, igual que en el detalle de habilidades activas.
#
# Cubre:
#   1. Al seleccionar la pasiva, se muestra "Efectos actuales" con el bono
#      YA aplicado (1 tier gratis, sin comprar nada todavía) y "Efectos en
#      el siguiente nivel" con el bono si se comprara un tier más — y el
#      texto de descripción original queda OCULTO (no solo vacío).
#   2. Tras comprar un tier con el botón "Mejorar", ambos bloques se
#      actualizan solos (sin reseleccionar la fila).
#   3. En el tope de niveles, ya no se muestra "Efectos en el siguiente
#      nivel" (no hay nada más que comprar).
#   4. Una pasiva de GATILLO (sin niveles, sin bono numérico) sigue
#      mostrando su descripción de texto tal cual — no tiene "efectos" que
#      listar (ya cubierto en prueba_panel_habilidades_pasivas.gd, se
#      reafirma acá de paso).
#   godot --headless --path . --script res://pruebas/prueba_panel_pasiva_efecto_por_nivel.gd
# =============================================================================
extends SceneTree

var _jugador
var _panel
var _pasiva: PasivaStatDesbloqueo
var _utils

var _efecto_actual_y_proximo_ok := false
var _se_actualiza_tras_comprar_ok := false
var _sin_proximo_nivel_al_tope_ok := false
var _gatillo_sin_lineas_de_efecto_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_efecto_inicial()
	_probar_tras_comprar()
	_probar_al_tope()
	_probar_gatillo_sin_efecto()
	return _informar()


func _montar() -> void:
	_utils = root.get_node("/root/Utils")

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	var experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	experiencia.name = "ExperienciaComponente"
	_pasiva = PasivaStatDesbloqueo.new()
	_pasiva.resource_path = "res://pruebas/fixtures/PasivaEfectoDePrueba.tres"
	_pasiva.nombre = "Piel de Prueba"
	_pasiva.descripcion = "Aumenta la resistencia física."
	_pasiva.nivel_requerido = 1
	_pasiva.max_niveles = 2
	_pasiva.costo_puntos_por_nivel = 1
	_pasiva.bono = AtributosBase.new()
	_pasiva.bono.resistencia_fisica = 5.0
	experiencia.pasivas_stat = [_pasiva] as Array[PasivaStatDesbloqueo]
	_jugador.add_child(experiencia)
	experiencia.agregar_xp(900)  # nivel alto -> puntos de sobra para comprar 2 tiers.

	var atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atributos.name = "AtributosComponente"
	atributos.base = AtributosBase.new()
	_jugador.add_child(atributos)
	atributos._ready()

	var mejoras = (load("res://componentes/MejorasComponente.gd") as GDScript).new()
	mejoras.name = "MejorasComponente"
	_jugador.add_child(mejoras)

	var slots = (load("res://componentes/SlotHabilidades.gd") as GDScript).new()
	slots.jugador = _jugador
	_jugador.add_child(slots)

	var pasivas = (load("res://componentes/PasivasComponente.gd") as GDScript).new()
	pasivas.name = "PasivasComponente"
	_jugador.add_child(pasivas)
	pasivas.desbloquear_gatillo("res://pruebas/fixtures/PasivaDePrueba.tscn")

	var escena := load("res://escenas/ui/panel_os/paneles/habilidades/PanelHabilidades.tscn") as PackedScene
	_panel = escena.instantiate()
	root.add_child(_panel)
	_panel.populate()


func _fila_de(nombre: String):
	for hijo in _panel.pasivas_list_panel.get_children():
		if hijo is ItemPasiva and hijo.nombre_pasiva.text == nombre:
			return hijo
	return null


## Cada fila de efecto es un HBoxContainer con [ColorRect, Label] — junta
## el texto de todas para comparar fácil (ver PanelDetallePasiva.
## _llenar_lista_efectos).
func _textos_de(contenedor: VBoxContainer) -> Array[String]:
	var textos: Array[String] = []
	for fila in contenedor.get_children():
		if fila is HBoxContainer and fila.get_child_count() >= 2:
			textos.append((fila.get_child(1) as Label).text)
	return textos


## nivel_requerido=1 ya la deja desbloqueada (1 tier gratis, sin comprar
## nada) — efectos actuales = bono x1, efectos del siguiente nivel = bono x2.
func _probar_efecto_inicial() -> void:
	_fila_de("Piel de Prueba").button_pressed = true
	var detalle = _panel.pasivas_detail_panel

	var actuales := _textos_de(detalle._lista_actuales)
	var proximo := _textos_de(detalle._lista_proximo)
	print("Efectos actuales (esperado +5 resistencia física): %s" % [actuales])
	print("Efectos siguiente nivel (esperado +10 resistencia física): %s" % [proximo])
	print("Descripción de texto oculta (esperado true): %s" % (not detalle.description_label.visible))
	_efecto_actual_y_proximo_ok = actuales == ["+5% resistencia física"] \
		and proximo == ["+10% resistencia física"] \
		and detalle._titulo_actuales.visible and detalle._titulo_proximo.visible \
		and not detalle.description_label.visible


## Comprar 1 tier (queda en 1/2) sin reseleccionar la fila — las listas
## tienen que reflejar el nuevo nivel solas.
func _probar_tras_comprar() -> void:
	var detalle = _panel.pasivas_detail_panel
	detalle._boton_mejorar.pressed.emit()

	var actuales := _textos_de(detalle._lista_actuales)
	var proximo := _textos_de(detalle._lista_proximo)
	print("Efectos actuales tras comprar (esperado +10 resistencia física): %s" % [actuales])
	print("Efectos siguiente nivel tras comprar (esperado +15 resistencia física): %s" % [proximo])
	_se_actualiza_tras_comprar_ok = actuales == ["+10% resistencia física"] \
		and proximo == ["+15% resistencia física"]


## Comprar el último tier disponible (max_niveles=2, ya en 1/2) — al llegar
## al tope no debe quedar ningún bloque de "siguiente nivel" (no hay nada
## más que comprar).
func _probar_al_tope() -> void:
	var detalle = _panel.pasivas_detail_panel
	detalle._boton_mejorar.pressed.emit()

	var actuales := _textos_de(detalle._lista_actuales)
	print("Efectos actuales al tope (esperado +15 resistencia física): %s" % [actuales])
	print("Bloque 'siguiente nivel' oculto al tope (esperado true): %s" % (not detalle._titulo_proximo.visible))
	_sin_proximo_nivel_al_tope_ok = actuales == ["+15% resistencia física"] \
		and not detalle._titulo_proximo.visible and not detalle._lista_proximo.visible


func _probar_gatillo_sin_efecto() -> void:
	_fila_de("Pasiva de Prueba").button_pressed = true
	var detalle = _panel.pasivas_detail_panel
	print("Descripción de gatillo (esperado 'descripción de prueba'): %s" % detalle.description_label.text)
	print("Descripción visible, sin listas de efectos (esperado true): %s" % \
		(detalle.description_label.visible and not detalle._titulo_actuales.visible))
	_gatillo_sin_lineas_de_efecto_ok = detalle.description_label.text == "descripción de prueba" \
		and detalle.description_label.visible and not detalle._titulo_actuales.visible


func _informar() -> bool:
	var exito := _efecto_actual_y_proximo_ok and _se_actualiza_tras_comprar_ok \
		and _sin_proximo_nivel_al_tope_ok and _gatillo_sin_lineas_de_efecto_ok
	print("  efecto actual y proximo nivel se muestran sin descripcion: %s" % _efecto_actual_y_proximo_ok)
	print("  se actualiza tras comprar: %s" % _se_actualiza_tras_comprar_ok)
	print("  sin siguiente nivel al tope: %s" % _sin_proximo_nivel_al_tope_ok)
	print("  gatillo sin lineas de efecto: %s" % _gatillo_sin_lineas_de_efecto_ok)
	print("PRUEBA PANEL PASIVA EFECTO POR NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
