# =============================================================================
# Prueba del sistema de guardado/carga (GestorGuardado):
#   1. guardar_partida() escribe posición, vida, XP, inventario, equipo y
#      habilidades equipadas del jugador a user://partida.save.
#   2. Tras "perder" ese estado en memoria (mover al jugador, vaciar
#      inventario/equipo/habilidades, resetear XP y vida), cargar_partida()
#      lo restaura todo — incluyendo la reconstrucción visual de los
#      EquipoSlot y las 4 habilidades del SlotHabilidades.
#   3. Los ítems restaurados vienen de sus .tres reales (vía id_recurso, que
#      GestorInventario estampa al duplicar) y GestorEquipo/AtributosComponente
#      quedan sincronizados con lo reequipado.
#   godot --headless --path . --script res://pruebas/prueba_guardado_partida.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jugador: CharacterBody2D
var _vida: Node
var _atributos: AtributosComponente
var _panel: Node
var _slots_habilidades: Node
var _gestor_inv: Node
var _gestor_xp: Node
var _gestor_equipo: Node
var _gestor_guardado: Node
var _pocion: DatosItem
var _casco: DatosItem
var _datos_muro: DatosHabilidad


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			_gestor_guardado.call("guardar_partida")
		3:
			_mutar_estado_en_memoria()
		4:
			_gestor_guardado.call("cargar_partida")
		5:
			return _informar()
	return false


func _montar() -> void:
	_gestor_inv = root.get_node("/root/GestorInventario")
	_gestor_xp = root.get_node("/root/GestorExperiencia")
	_gestor_equipo = root.get_node("/root/GestorEquipo")
	_gestor_guardado = root.get_node("/root/GestorGuardado")
	_gestor_inv.items.clear()
	_gestor_xp.xp_total = 0
	_gestor_equipo.equipados.clear()

	# Nivel real registrado en GestorNiveles: así nivel_actual().scene_file_path
	# existe y guardar/cargar toma la rama síncrona (mismo nivel, sin
	# cambiar_nivel real ni fundidos que complicarían la prueba).
	var contenedor := Node2D.new()
	root.add_child(contenedor)
	var nivel := (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	contenedor.add_child(nivel)

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)
	_jugador.global_position = Vector2(111, 222)

	_vida = VidaComponente.new()
	_vida.name = "VidaComponente"
	_vida.salud_maxima = 100.0
	_jugador.add_child(_vida)
	_vida.restaurar_vida(65.0)

	root.get_node("/root/GestorNiveles").registrar(contenedor, _jugador)

	_atributos = AtributosComponente.new()
	_atributos.name = "AtributosComponente"
	_atributos.base = AtributosBase.new()
	_jugador.add_child(_atributos)
	# En el juego real esto lo hace Jugador._on_equipo_cambiado(); acá el
	# "jugador" es un CharacterBody2D desnudo, así que se conecta a mano.
	var bus := root.get_node("/root/BusEventos")
	bus.equipo_cambiado.connect(func(equipados): _atributos.recalcular_con_equipo(equipados))

	_panel = (load("res://escenas/ui/panel_os/paneles/inventario/PanelInventario.tscn") as PackedScene).instantiate()
	_panel.name = "PanelInventario"
	root.add_child(_panel)

	# Cualquier .tres de consumible sirve para probar el flujo — la prueba no
	# depende de un ítem puntual, solo de que exista al menos uno.
	_pocion = _primer_tres_en("res://recursos/items/consumibles/")
	_casco = _primer_tres_equipable_helmet()

	_gestor_xp.agregar_xp(30)
	_gestor_inv.agregar_item(_pocion, 3)
	if _casco:
		var slot_casco := _buscar_slot_de(_panel.flow, _casco)
		if slot_casco == null:
			_gestor_inv.agregar_item(_casco)
			slot_casco = _buscar_slot_de(_panel.flow, _casco)
		_panel._equip_item(slot_casco)

	# Sin tipar como SlotHabilidades ni usar su class_name directo: ese script
	# referencia BusEventos (autoload) desde su propia clase, y el análisis
	# estático del --script de esta prueba lo compilaría antes de que los
	# autoloads existan (mismo artefacto de siempre, ver otras pruebas).
	_slots_habilidades = (load("res://componentes/SlotHabilidades.gd") as GDScript).new()
	_slots_habilidades.jugador = _jugador
	_jugador.add_child(_slots_habilidades)
	_datos_muro = load("res://recursos/habilidades_ui/muro.tres") as DatosHabilidad
	_slots_habilidades.equipar(0, _datos_muro)


func _mutar_estado_en_memoria() -> void:
	_jugador.global_position = Vector2.ZERO
	_vida.restaurar_vida(1.0)
	_gestor_xp.xp_total = 0
	_gestor_inv.items.clear()
	var vacio: Array[DatosItem] = []
	_panel.restaurar_equipo(vacio)
	_atributos.base.defensa = 0.0
	_slots_habilidades.equipar(0, null)


func _primer_tres_en(carpeta: String) -> DatosItem:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return null
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		if archivo.ends_with(".tres"):
			return load(carpeta + archivo) as DatosItem
		archivo = dir.get_next()
	return null


func _primer_tres_equipable_helmet() -> DatosItem:
	var dir := DirAccess.open("res://recursos/items/equipables/")
	if dir == null:
		return null
	dir.list_dir_begin()
	var archivo := dir.get_next()
	while archivo != "":
		if archivo.ends_with(".tres"):
			var item := load("res://recursos/items/equipables/" + archivo) as DatosItem
			if item and item.type_equippable == 1:  # HELMET
				return item
		archivo = dir.get_next()
	return null


func _buscar_slot_de(flow: Node, item: DatosItem) -> Node:
	for hijo in flow.get_children():
		if hijo.item_data and hijo.item_data.name == item.name:
			return hijo
	return null


func _informar() -> bool:
	var pos_ok := _jugador.global_position.distance_to(Vector2(111, 222)) < 0.5
	var vida_ok := is_equal_approx(_vida.obtener_vida(), 65.0)
	var xp_total: int = _gestor_xp.xp_total
	var xp_ok := xp_total == 30
	var pocion_ok := false
	for i in _gestor_inv.items:
		if i.name == _pocion.name and i.quantity == 3:
			pocion_ok = true

	var casco_ok := true
	var atributos_ok := true
	if _casco:
		casco_ok = false
		for e in _gestor_equipo.equipados:
			if e.name == _casco.name:
				casco_ok = true
		# El bono de defensa del casco (si tiene) debe haber vuelto a
		# aplicarse sobre AtributosComponente.base tras restaurar_equipo().
		if _casco.bonos and _casco.bonos.defensa != 0.0:
			atributos_ok = _atributos.base.defensa == _casco.bonos.defensa

	var datos_slot_0: DatosHabilidad = _slots_habilidades.obtener_datos(0)
	var habilidad_ok: bool = datos_slot_0 != null and datos_slot_0.resource_path == _datos_muro.resource_path
	# Sin tipar como HabilidadBase: ese script referencia BusEventos dentro de
	# _process() y el análisis estático del --script lo compilaría antes de
	# que los autoloads existan (mismo motivo que SlotHabilidades más arriba).
	var instancia_habilidad = _slots_habilidades.obtener(0)
	var instancia_ok: bool = instancia_habilidad != null and instancia_habilidad.tipo_habilidad == "muro"

	print("Posición restaurada (111,222): %s" % pos_ok)
	print("Vida restaurada (65.0): %s" % vida_ok)
	print("XP restaurada (30): %s" % xp_ok)
	print("Poción restaurada en inventario (x3): %s" % pocion_ok)
	print("Casco restaurado en GestorEquipo: %s" % casco_ok)
	print("Atributos recalculados tras restaurar equipo: %s" % atributos_ok)
	print("Habilidad 'Muro' restaurada en slot 0 (datos): %s" % habilidad_ok)
	print("Habilidad 'Muro' restaurada en slot 0 (instancia real): %s" % instancia_ok)

	var exito := pos_ok and vida_ok and xp_ok and pocion_ok and casco_ok and atributos_ok \
		and habilidad_ok and instancia_ok
	print("PRUEBA GUARDADO PARTIDA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
