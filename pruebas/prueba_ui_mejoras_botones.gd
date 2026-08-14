# =============================================================================
# Prueba de los botones de "Mejorar"/"Subir nivel" recién cableados (ver
# PanelDetallePasiva.gd y PanelDetalleHabilidad.gd) — que el CLIC de verdad
# gaste el punto (no solo la lógica de MejorasComponente, ya cubierta en
# prueba_mejoras_gastar_en_*.gd) y que la UI se refresque sola.
#
# Cubre:
#   1. Pasiva de ESTADÍSTICA seleccionada: el botón "Mejorar" aparece, y
#      tocarlo gasta el punto (nivel_pasiva sube, el indicador de puntos
#      de PanelHabilidades baja).
#   2. Pasiva de GATILLO seleccionada: el botón "Mejorar" queda oculto (no
#      tiene niveles que comprar).
#   3. Habilidad ACTIVA: "Subir nivel" gasta un punto y sube nivel_mejora
#      de la instancia equipada, reflejado en el label sin reseleccionar.
#   4. Habilidad ACTIVA sin escalado configurado (DatosHabilidad.escalado ==
#      null): el botón "Subir nivel" queda OCULTO por completo (ver
#      PanelDetalleHabilidad.show_skill) — no un botón deshabilitado.
#   5. Las FILAS de la lista (ItemPasiva/ItemHabilidad) muestran el nivel
#      de mejora real y se actualizan solas al comprar — antes ninguna de
#      las dos reflejaba nada (ItemPasiva no mostraba ningún nivel;
#      ItemHabilidad mostraba el nivel de CATÁLOGO, que nunca cambia),
#      reportado por el usuario: "las habilidades activas no cambian el
#      nivel en la lista al igual que las pasivas".
#   godot --headless --path . --script res://pruebas/prueba_ui_mejoras_botones.gd
# =============================================================================
extends SceneTree

const RUTA_PASIVA_GATILLO := "res://pruebas/fixtures/PasivaDePrueba.tscn"

var _jugador
var _panel
var _pasiva_stat: PasivaStatDesbloqueo
var _utils

var _boton_mejorar_visible_en_stat_ok := false
var _mejorar_gasta_punto_ok := false
var _boton_oculto_en_gatillo_ok := false
var _subir_nivel_gasta_punto_ok := false
var _boton_oculto_sin_escalado_ok := false
var _panel_muestra_dano_escalado_ok := false
var _fila_pasiva_actualiza_nivel_ok := false
var _fila_activa_actualiza_nivel_ok := false
var _boton_sin_puntos_explica_ok := false
var _equipada_se_muestra_ok := false
var _boton_nivel_maximo_explica_ok := false
var _boton_reiniciar_habilitado_ok := false
var _reiniciar_devuelve_puntos_ok := false
var _reiniciar_actualiza_fila_ok := false
var _reiniciar_deshabilita_boton_ok := false
var _descripcion_sacrificio_escala_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_pasiva_stat()
	_probar_pasiva_gatillo()
	_probar_habilidad_activa()
	_probar_boton_reiniciar_puntos()
	_probar_descripcion_sacrificio_escala_con_nivel()
	_probar_boton_oculto_sin_escalado()
	return _informar()


func _montar() -> void:
	_utils = root.get_node("/root/Utils")

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	var experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	experiencia.name = "ExperienciaComponente"
	_pasiva_stat = PasivaStatDesbloqueo.new()
	_pasiva_stat.resource_path = "res://pruebas/fixtures/PasivaStatUiDePrueba.tres"
	_pasiva_stat.nivel_requerido = 1
	_pasiva_stat.max_niveles = 5
	_pasiva_stat.costo_puntos_por_nivel = 1
	_pasiva_stat.bono = AtributosBase.new()
	_pasiva_stat.bono.defensa = 3.0
	experiencia.pasivas_stat = [_pasiva_stat] as Array[PasivaStatDesbloqueo]
	_jugador.add_child(experiencia)
	experiencia.agregar_xp(900)  # nivel bien alto -> muchos puntos disponibles

	var atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atributos.name = "AtributosComponente"
	atributos.base = AtributosBase.new()
	_jugador.add_child(atributos)
	atributos._ready()

	var mejoras = (load("res://componentes/MejorasComponente.gd") as GDScript).new()
	mejoras.name = "MejorasComponente"
	_jugador.add_child(mejoras)

	var pasivas = (load("res://componentes/PasivasComponente.gd") as GDScript).new()
	pasivas.name = "PasivasComponente"
	_jugador.add_child(pasivas)
	pasivas.desbloquear_gatillo(RUTA_PASIVA_GATILLO)

	var slots = (load("res://componentes/SlotHabilidades.gd") as GDScript).new()
	slots.name = "SlotHabilidades"
	slots.jugador = _jugador
	_jugador.add_child(slots)
	var datos_muro := load("res://recursos/habilidades/muro.tres") as DatosHabilidad
	# Escalado de prueba EN MEMORIA (no se guarda a disco) — sin esto,
	# _gastar_en_habilidad_local rechaza el gasto (escalado == null, ver
	# MejorasComponente._gastar_en_habilidad_local).
	var escalado_muro := EscaladoHabilidad.new()
	var c_min := CampoEscaladoTabla.new()
	c_min.campo = Enums.Habilidad.CampoEscalable.DANO_MIN
	c_min.valores_por_nivel = [3.0, 5.0, 7.0]
	var c_max := CampoEscaladoTabla.new()
	c_max.campo = Enums.Habilidad.CampoEscalable.DANO_MAX
	c_max.valores_por_nivel = [6.0, 9.0, 12.0]
	escalado_muro.campos = [c_min, c_max] as Array[CampoEscalado]
	escalado_muro.nivel_maximo = 3
	escalado_muro.costo_puntos_por_nivel = 1
	datos_muro.escalado = escalado_muro
	# El catálogo (no solo lo equipado) es lo que puebla la lista de la
	# pestaña "Activas" — ver PanelHabilidades.populate().
	slots.catalogo = [datos_muro] as Array[DatosHabilidad]
	slots.equipar(0, datos_muro)

	var escena := load("res://escenas/ui/panel_os/paneles/habilidades/PanelHabilidades.tscn") as PackedScene
	_panel = escena.instantiate()
	root.add_child(_panel)
	_panel.populate()


func _fila_pasiva_de(nombre: String):
	for hijo in _panel.pasivas_list_panel.get_children():
		if hijo is ItemPasiva and hijo.nombre_pasiva.text == nombre:
			return hijo
	return null


func _probar_pasiva_stat() -> void:
	var fila = _fila_pasiva_de(_pasiva_stat.nombre)
	fila.button_pressed = true

	print("Puntos de progreso en la fila ANTES de comprar (esperado 1/6, el desbloqueo ya da 1 tier gratis): %d/%d" % [
		fila._indicador_puntos.tier, fila._indicador_puntos.max_tier])
	var nivel_fila_antes_ok: bool = fila._indicador_puntos.tier == 1 and fila._indicador_puntos.max_tier == 6

	var boton: Button = _panel.pasivas_detail_panel._boton_mejorar
	print("Fila de mejorar visible para pasiva de stat (esperado true): %s" % \
		_panel.pasivas_detail_panel._fila_mejorar.visible)
	_boton_mejorar_visible_en_stat_ok = _panel.pasivas_detail_panel._fila_mejorar.visible

	var mejoras = _utils.mejoras_componente_local()
	var puntos_antes: int = mejoras.puntos_disponibles()
	var defensa_antes: float = _jugador.get_node("AtributosComponente").base.defensa

	boton.pressed.emit()

	var defensa_despues: float = _jugador.get_node("AtributosComponente").base.defensa
	print("Defensa tras tocar Mejorar (esperado %.1f = %.1f + 3): %.1f" % [
		defensa_antes + 3.0, defensa_antes, defensa_despues])
	print("Puntos de PanelHabilidades tras el gasto (esperado %d): %s" % [
		puntos_antes - 1, _panel._etiqueta_puntos.text])
	_mejorar_gasta_punto_ok = is_equal_approx(defensa_despues, defensa_antes + 3.0) \
		and _panel._etiqueta_puntos.text == "Puntos: %d" % (puntos_antes - 1)

	print("Puntos de progreso en la fila tras comprar (esperado 2/6): %d/%d" % [
		fila._indicador_puntos.tier, fila._indicador_puntos.max_tier])
	_fila_pasiva_actualiza_nivel_ok = nivel_fila_antes_ok \
		and fila._indicador_puntos.tier == 2 and fila._indicador_puntos.max_tier == 6

	# Sin puntos disponibles, el botón tiene que decir POR QUÉ está
	# deshabilitado, no solo mostrar el mismo texto de costo de siempre
	# (pedido del usuario). Se restaura el gasto real apenas se lee el
	# texto, para no dejar a las pruebas siguientes sin puntos de verdad.
	var gastados_reales: int = mejoras.puntos_gastados
	mejoras.puntos_gastados = mejoras.puntos_disponibles() + mejoras.puntos_gastados  # deja 0 disponibles
	_panel.pasivas_detail_panel.show_pasiva(
		_pasiva_stat.nombre, _pasiva_stat.descripcion, _pasiva_stat.icono, _pasiva_stat)
	print("Texto del botón sin puntos suficientes (esperado 'Sin puntos suficientes'): %s" % boton.text)
	_boton_sin_puntos_explica_ok = boton.text == "Sin puntos suficientes" and boton.disabled
	mejoras.puntos_gastados = gastados_reales


func _probar_pasiva_gatillo() -> void:
	var fila = _fila_pasiva_de("Pasiva de Prueba")
	fila.button_pressed = true
	print("Fila de mejorar OCULTA para pasiva de gatillo (esperado true): %s" % \
		(not _panel.pasivas_detail_panel._fila_mejorar.visible))
	_boton_oculto_en_gatillo_ok = not _panel.pasivas_detail_panel._fila_mejorar.visible


func _probar_habilidad_activa() -> void:
	var mejoras = _utils.mejoras_componente_local()
	var nivel_antes: int = mejoras.nivel_habilidad("res://recursos/habilidades/muro.tres")

	_panel._on_btn_activas()
	# Único ítem del catálogo (ver _montar) — ya viene auto-seleccionado
	# desde populate(), pero se reafirma para no depender de ese detalle.
	var item: ItemHabilidad = _panel.skill_list_panel.get_child(0)
	_panel._on_skill_selected(item.skill_data)

	# Ya está equipada en el slot 0 (ver _montar) — tiene que verse en la
	# fila de la lista Y en el detalle, pedido del usuario ("indicador de
	# equipado en la lista").
	print("Insignia 'equipada' en la fila de la lista (esperado true): %s" % item._insignia_equipada.visible)
	print("Insignia 'equipada' en el panel de detalle (esperado true): %s" % \
		_panel.detail_panel._etiqueta_equipada.visible)
	_equipada_se_muestra_ok = item._insignia_equipada.visible and _panel.detail_panel._etiqueta_equipada.visible

	print("Puntos de progreso en la fila ANTES de subir (esperado 1/3): %d/%d" % [
		item._indicador_puntos.tier, item._indicador_puntos.max_tier])
	var nivel_fila_antes_ok: bool = item._indicador_puntos.tier == 1 and item._indicador_puntos.max_tier == 3

	_panel.detail_panel._uplevel_btn.pressed.emit()

	var nivel_despues: int = mejoras.nivel_habilidad("res://recursos/habilidades/muro.tres")
	print("Nivel de mejora de 'muro' tras Subir nivel (esperado %d): %d" % [nivel_antes + 1, nivel_despues])
	_subir_nivel_gasta_punto_ok = nivel_despues == nivel_antes + 1

	print("Puntos de progreso en la fila tras subir (esperado 2/3): %d/%d" % [
		item._indicador_puntos.tier, item._indicador_puntos.max_tier])
	_fila_activa_actualiza_nivel_ok = nivel_fila_antes_ok \
		and item._indicador_puntos.tier == 2 and item._indicador_puntos.max_tier == 3

	# El panel mostraba SIEMPRE el daño de fábrica (nivel 1) sin importar
	# cuánto se hubiera invertido — reportado por el usuario ("no se ve
	# afectado por la subida de nivel"). Ver PanelDetalleHabilidad.show_skill.
	var datos_muro: DatosHabilidad = item.skill_data
	var nivel_mejora_actual := 1 + nivel_despues
	var dano_min_esperado: int = int(datos_muro.escalado.valor_para_campo(
		Enums.Habilidad.CampoEscalable.DANO_MIN, nivel_mejora_actual, datos_muro.damage_base_min))
	var dano_max_esperado: int = int(datos_muro.escalado.valor_para_campo(
		Enums.Habilidad.CampoEscalable.DANO_MAX, nivel_mejora_actual, datos_muro.damage_base_max))
	var texto_esperado := "%d - %d" % [dano_min_esperado, dano_max_esperado]
	print("Daño base mostrado en el panel tras subir de nivel (esperado %s): %s" % [
		texto_esperado, _panel.detail_panel.dmg_base_label.text])
	_panel_muestra_dano_escalado_ok = _panel.detail_panel.dmg_base_label.text == texto_esperado

	# Al tope (nivel_maximo=3, ya en 2/3): un gasto más lo lleva al tope —
	# el botón tiene que decirlo explícitamente, no quedar deshabilitado
	# sin explicación (pedido del usuario).
	_panel.detail_panel._uplevel_btn.pressed.emit()
	print("Texto del botón al tope (esperado 'Nivel máximo'): %s" % _panel.detail_panel._uplevel_btn.text)
	_boton_nivel_maximo_explica_ok = _panel.detail_panel._uplevel_btn.text == "Nivel máximo" \
		and _panel.detail_panel._uplevel_btn.disabled


## Pedido del usuario: "un botón al lado de los puntos de habilidad
## disponibles para reiniciarlos". A esta altura ya hay puntos gastados de
## verdad (la pasiva de stat arriba, y muro al tope) — estado real para
## probar el botón, no uno armado a mano.
func _probar_boton_reiniciar_puntos() -> void:
	var boton: Button = _panel._boton_reiniciar_puntos
	print("Botón reiniciar HABILITADO con puntos gastados (esperado true): %s" % (not boton.disabled))
	_boton_reiniciar_habilitado_ok = not boton.disabled

	var mejoras = _utils.mejoras_componente_local()
	var puntos_totales: int = mejoras.puntos_disponibles() + mejoras.puntos_gastados

	boton.pressed.emit()

	print("puntos_disponibles() vuelve al total tras reiniciar (esperado %d): %d" % [
		puntos_totales, mejoras.puntos_disponibles()])
	_reiniciar_devuelve_puntos_ok = mejoras.puntos_disponibles() == puntos_totales

	var fila = _fila_pasiva_de(_pasiva_stat.nombre)
	var item: ItemHabilidad = _panel.skill_list_panel.get_child(0)
	print("Fila de pasiva vuelve a 1/6 (esperado true): %d/%d" % [
		fila._indicador_puntos.tier, fila._indicador_puntos.max_tier])
	print("Fila de muro vuelve a 1/3 (esperado true): %d/%d" % [
		item._indicador_puntos.tier, item._indicador_puntos.max_tier])
	_reiniciar_actualiza_fila_ok = fila._indicador_puntos.tier == 1 and item._indicador_puntos.tier == 1

	print("Botón reiniciar DESHABILITADO sin nada que reiniciar (esperado true): %s" % boton.disabled)
	_reiniciar_deshabilita_boton_ok = boton.disabled


## HabilidadSacrificio: a diferencia del daño (dano_min_mostrado/etc., ya
## cubierto arriba con muro), sus 3 campos escalados (potencia/prob.
## crítico/daño crítico) solo se ven a través de la DESCRIPCIÓN
## ({valor1}/{valor2}/{valor3}, ver sacrificio.tres) — reportado por el
## usuario: "no se actualiza en el detalle cuando subo de nivel la
## habilidad". La causa era que PanelDetalleHabilidad.show_skill() armaba
## esos placeholders desde una instancia SIN aplicar_datos()/preparar_
## escalado()/aplicar_nivel_mejora() — siempre mostraba el valor de
## FÁBRICA (nivel 1), sin importar el nivel comprado.
func _probar_descripcion_sacrificio_escala_con_nivel() -> void:
	var datos_sacrificio := load("res://recursos/habilidades/sacrificio.tres") as DatosHabilidad
	var slots = _jugador.get_node("SlotHabilidades")
	slots.catalogo.append(datos_sacrificio)
	slots.equipar(1, datos_sacrificio)

	# equipar() no reconstruye la lista de la pestaña Activas — solo
	# populate() lee slots.catalogo de nuevo (ver PanelHabilidades.gd).
	_panel.populate()
	_panel._on_btn_activas()
	var item_sacrificio: ItemHabilidad = null
	for hijo in _panel.skill_list_panel.get_children():
		if hijo is ItemHabilidad and hijo.skill_data.resource_path == datos_sacrificio.resource_path:
			item_sacrificio = hijo
			break
	_panel._on_skill_selected(item_sacrificio.skill_data)

	print("Descripción en nivel 1 (esperado que contenga '+100'): %s" % _panel.detail_panel.description_label.text)
	var nivel1_ok: bool = "+100" in _panel.detail_panel.description_label.text

	for i in range(4):  # nivel 1 -> nivel 5 (escalado de sacrificio.tres llega a nivel_maximo=5)
		_panel.detail_panel._uplevel_btn.pressed.emit()

	print("Descripción en nivel 5 tras subir (esperado que contenga '+200'): %s" % _panel.detail_panel.description_label.text)
	var nivel5_ok: bool = "+200" in _panel.detail_panel.description_label.text

	_descripcion_sacrificio_escala_ok = nivel1_ok and nivel5_ok


## Habilidad SIN escalado configurado (DatosHabilidad.escalado == null) —
## no hace falta equiparla ni que tenga escena_al_impactar/lo que sea, solo
## seleccionarla (ver PanelHabilidades._on_skill_selected, que llama a
## show_skill directo, sin pasar por el catálogo).
func _probar_boton_oculto_sin_escalado() -> void:
	var datos_sin_escalado := DatosHabilidad.new()
	datos_sin_escalado.resource_path = "res://pruebas/fixtures/HabilidadSinEscaladoUiDePrueba.tres"
	datos_sin_escalado.nombre = "Habilidad Sin Escalado (prueba)"
	datos_sin_escalado.escalado = null

	_panel._on_btn_activas()
	_panel._on_skill_selected(datos_sin_escalado)

	print("Boton Subir nivel OCULTO sin escalado configurado (esperado true): %s" % \
		(not _panel.detail_panel._uplevel_btn.visible))
	_boton_oculto_sin_escalado_ok = not _panel.detail_panel._uplevel_btn.visible


func _informar() -> bool:
	var exito := _boton_mejorar_visible_en_stat_ok and _mejorar_gasta_punto_ok \
		and _boton_oculto_en_gatillo_ok and _subir_nivel_gasta_punto_ok \
		and _boton_oculto_sin_escalado_ok and _panel_muestra_dano_escalado_ok \
		and _fila_pasiva_actualiza_nivel_ok and _fila_activa_actualiza_nivel_ok \
		and _boton_sin_puntos_explica_ok and _equipada_se_muestra_ok and _boton_nivel_maximo_explica_ok \
		and _boton_reiniciar_habilitado_ok and _reiniciar_devuelve_puntos_ok \
		and _reiniciar_actualiza_fila_ok and _reiniciar_deshabilita_boton_ok \
		and _descripcion_sacrificio_escala_ok
	print("  boton Mejorar visible en pasiva de stat: %s" % _boton_mejorar_visible_en_stat_ok)
	print("  tocar Mejorar gasta el punto de verdad: %s" % _mejorar_gasta_punto_ok)
	print("  boton Mejorar oculto en pasiva de gatillo: %s" % _boton_oculto_en_gatillo_ok)
	print("  Subir nivel en habilidad activa gasta el punto: %s" % _subir_nivel_gasta_punto_ok)
	print("  boton Subir nivel oculto sin escalado configurado: %s" % _boton_oculto_sin_escalado_ok)
	print("  panel muestra el dano ya escalado tras subir de nivel: %s" % _panel_muestra_dano_escalado_ok)
	print("  fila de pasiva en la lista actualiza su nivel: %s" % _fila_pasiva_actualiza_nivel_ok)
	print("  fila de habilidad activa en la lista actualiza su nivel: %s" % _fila_activa_actualiza_nivel_ok)
	print("  boton sin puntos explica el motivo: %s" % _boton_sin_puntos_explica_ok)
	print("  insignia de equipada se muestra en lista y detalle: %s" % _equipada_se_muestra_ok)
	print("  boton al tope explica el motivo: %s" % _boton_nivel_maximo_explica_ok)
	print("  boton reiniciar habilitado con puntos gastados: %s" % _boton_reiniciar_habilitado_ok)
	print("  reiniciar devuelve todos los puntos: %s" % _reiniciar_devuelve_puntos_ok)
	print("  reiniciar actualiza las filas de la lista: %s" % _reiniciar_actualiza_fila_ok)
	print("  boton reiniciar se deshabilita sin nada que reiniciar: %s" % _reiniciar_deshabilita_boton_ok)
	print("  descripcion de Sacrificio escala con el nivel: %s" % _descripcion_sacrificio_escala_ok)
	print("PRUEBA UI MEJORAS BOTONES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
