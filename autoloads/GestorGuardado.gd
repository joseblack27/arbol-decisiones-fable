extends Node
## GestorGuardado (autoload): guarda y carga el progreso del jugador en
## disco (user://partida.save, formato JSON legible).
##
## Cubre: nivel actual, posición y vida del jugador, inventario, equipo,
## habilidades equipadas en los 4 slots y experiencia. NO guarda estados de
## mundo (mobs vivos/muertos, cooldowns de spawners, etc.) — al cargar, el
## nivel se reinstancia desde cero como si acabaras de entrar a él.
##
## Se dispara con F5 (guardar) / F9 (cargar) desde cualquier parte del
## juego, o con los botones "Guardar"/"Cargar" del panel OS
## (ver OsPrincipal.gd).

const RUTA_GUARDADO := "user://partida.save"
const VERSION_GUARDADO := 1

signal partida_guardada
signal partida_cargada


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5:
		guardar_partida()
	elif event.keycode == KEY_F9:
		cargar_partida()


func existe_partida() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


func guardar_partida() -> void:
	var jugador := _obtener_jugador()
	if jugador == null:
		push_warning("GestorGuardado: no hay jugador en escena, no se puede guardar.")
		return

	var nivel := GestorNiveles.nivel_actual()
	var vida: VidaComponente = jugador.get_node_or_null("VidaComponente")

	var datos := {
		"version": VERSION_GUARDADO,
		"nivel_escena": nivel.scene_file_path if nivel else "",
		"jugador": {
			"posicion": [jugador.global_position.x, jugador.global_position.y],
			"vida_actual": vida.obtener_vida() if vida else 0.0,
		},
		"xp_total": GestorExperiencia.xp_total,
		"inventario": _serializar_items(GestorInventario.items),
		"equipo": _serializar_items(GestorEquipo.equipados),
		"habilidades": _serializar_habilidades(),
	}

	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		push_error("GestorGuardado: no se pudo abrir '%s' para escribir (error %d)." % [RUTA_GUARDADO, FileAccess.get_open_error()])
		return
	archivo.store_string(JSON.stringify(datos))
	archivo.close()
	partida_guardada.emit()


func cargar_partida() -> void:
	if not existe_partida():
		push_warning("GestorGuardado: no hay ninguna partida guardada.")
		return

	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if archivo == null:
		push_error("GestorGuardado: no se pudo abrir '%s' para leer (error %d)." % [RUTA_GUARDADO, FileAccess.get_open_error()])
		return
	var texto := archivo.get_as_text()
	archivo.close()

	var resultado: Variant = JSON.parse_string(texto)
	if typeof(resultado) != TYPE_DICTIONARY:
		push_error("GestorGuardado: archivo de guardado corrupto o ilegible.")
		return
	var datos: Dictionary = resultado

	var nivel_destino: String = datos.get("nivel_escena", "")
	var nivel_actual := GestorNiveles.nivel_actual()
	var ya_en_ese_nivel := nivel_destino == "" or (nivel_actual != null and nivel_actual.scene_file_path == nivel_destino)

	if ya_en_ese_nivel:
		_aplicar_datos_partida(datos)
	else:
		# GestorNiveles.cambiar_nivel() reposiciona al jugador en el punto de
		# aparición del nivel nuevo — hay que esperar a que termine para
		# recién ahí pisar esa posición con la guardada.
		GestorNiveles.nivel_cargado.connect(_al_cambiar_nivel.bind(datos), CONNECT_ONE_SHOT)
		GestorNiveles.cambiar_nivel(nivel_destino)


func _al_cambiar_nivel(_nivel: NivelBase, datos: Dictionary) -> void:
	_aplicar_datos_partida(datos)


func _aplicar_datos_partida(datos: Dictionary) -> void:
	var jugador := _obtener_jugador()
	if jugador == null:
		return

	var datos_jugador: Dictionary = datos.get("jugador", {})
	var pos: Array = datos_jugador.get("posicion", [])
	if pos.size() == 2:
		jugador.global_position = Vector2(pos[0], pos[1])

	var vida: VidaComponente = jugador.get_node_or_null("VidaComponente")
	if vida:
		vida.restaurar_vida(datos_jugador.get("vida_actual", vida.obtener_vida_maxima()))

	GestorExperiencia.xp_total = datos.get("xp_total", 0)

	GestorInventario.items.clear()
	for entrada in datos.get("inventario", []):
		var item := _cargar_item(entrada)
		if item:
			GestorInventario.agregar_item(item, entrada.get("cantidad", 1))

	_restaurar_equipo(datos.get("equipo", []))
	_restaurar_habilidades(datos.get("habilidades", []))

	partida_cargada.emit()


func _serializar_items(items: Array) -> Array:
	var lista := []
	for item: DatosItem in items:
		if item == null or item.id_recurso == "":
			continue
		lista.append({"id_recurso": item.id_recurso, "cantidad": item.quantity})
	return lista


func _cargar_item(entrada: Dictionary) -> DatosItem:
	var ruta: String = entrada.get("id_recurso", "")
	if ruta == "" or not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as DatosItem


func _restaurar_equipo(entradas: Array) -> void:
	var panel := get_tree().get_root().find_child("PanelInventario", true, false)
	if panel == null or not panel.has_method("restaurar_equipo"):
		return
	var items: Array[DatosItem] = []
	for entrada in entradas:
		var item := _cargar_item(entrada)
		if item:
			items.append(item)
	panel.call("restaurar_equipo", items)


## A diferencia de DatosItem, un DatosHabilidad NUNCA se duplica (SlotHabilidades
## solo guarda la referencia que ya trae su "catalogo") — su resource_path es
## siempre válido, sin necesitar el mismo truco de id_recurso que los ítems.
func _serializar_habilidades() -> Array:
	var slots := get_tree().get_first_node_in_group("slot_habilidades")
	var lista := []
	if slots == null:
		return lista
	for i in 4:
		var datos: DatosHabilidad = slots.obtener_datos(i)
		lista.append(datos.resource_path if datos else "")
	return lista


func _restaurar_habilidades(rutas: Array) -> void:
	var slots := get_tree().get_first_node_in_group("slot_habilidades")
	if slots == null:
		return
	for i in 4:
		var ruta: String = rutas[i] if i < rutas.size() else ""
		if ruta != "" and ResourceLoader.exists(ruta):
			slots.equipar(i, load(ruta) as DatosHabilidad)
		else:
			slots.equipar(i, null)


func _obtener_jugador() -> Node2D:
	return get_tree().get_first_node_in_group("jugadores") as Node2D
