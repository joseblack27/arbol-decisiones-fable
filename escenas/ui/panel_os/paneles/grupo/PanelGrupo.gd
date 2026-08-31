extends Control
## Pestaña "Grupo" del OS — Feature C del plan MMO. Sin grupo: lista de
## jugadores conectados con botón "Invitar" por fila (decisión del usuario:
## panel dedicado, no comando de chat). En grupo: lista de miembros con
## nombre + mini barra de vida, botón "Salir", y "Expulsar" por fila solo
## si sos el líder (única restricción de "rol" — administración del grupo,
## no ventaja de combate, ver GestorGrupos.gd).

@onready var _etiqueta_estado: Label = $VBox/EtiquetaEstado
@onready var _lista_roster: VBoxContainer = $VBox/Scroll/Contenido/ListaRoster
@onready var _lista_grupo: VBoxContainer = $VBox/Scroll/Contenido/ListaGrupo
@onready var _boton_salir: Button = $VBox/BotonSalir


func _ready() -> void:
	_boton_salir.pressed.connect(GestorGrupos.salir_del_grupo)
	GestorGrupos.roster_actualizado.connect(_actualizar)
	GestorGrupos.grupo_actualizado.connect(_actualizar)
	_actualizar()


func _actualizar() -> void:
	for hijo in _lista_roster.get_children():
		hijo.queue_free()
	for hijo in _lista_grupo.get_children():
		hijo.queue_free()

	var grupo: Dictionary = GestorGrupos.mi_grupo
	var en_grupo := not grupo.is_empty()
	_lista_grupo.visible = en_grupo
	_lista_roster.visible = not en_grupo
	_boton_salir.visible = en_grupo

	if en_grupo:
		var miembros: Array = grupo.get("miembros", [])
		_etiqueta_estado.text = "Grupo (%d/%d)" % [miembros.size(), GestorGrupos.TAMANO_MAXIMO_GRUPO]
		var soy_lider: bool = grupo.get("soy_lider", false)
		var id_lider: String = str(grupo.get("lider", ""))
		for miembro: Dictionary in miembros:
			_lista_grupo.add_child(_fila_miembro(miembro, soy_lider, id_lider))
	else:
		_etiqueta_estado.text = "Sin grupo — jugadores conectados:"
		for entrada: Dictionary in GestorGrupos.roster:
			if int(entrada.get("peer_id", -1)) == multiplayer.get_unique_id():
				continue  # no invitarte a vos mismo.
			_lista_roster.add_child(_fila_roster(entrada))


func _fila_roster(entrada: Dictionary) -> Control:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = str(entrada.get("nombre", ""))
	nombre.custom_minimum_size = Vector2(140, 0)
	fila.add_child(nombre)
	var boton_invitar := Button.new()
	boton_invitar.text = "Invitar"
	var peer_id: int = int(entrada.get("peer_id", -1))
	boton_invitar.pressed.connect(func() -> void: GestorGrupos.invitar(peer_id))
	fila.add_child(boton_invitar)
	return fila


func _fila_miembro(miembro: Dictionary, soy_lider: bool, id_lider: String) -> Control:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = str(miembro.get("nombre", ""))
	nombre.custom_minimum_size = Vector2(120, 0)
	fila.add_child(nombre)

	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = maxf(1.0, float(miembro.get("vida_maxima", 1.0)))
	barra.value = float(miembro.get("vida", 0.0))
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(90, 14)
	fila.add_child(barra)

	# El líder ve "Expulsar" en cada fila salvo la propia (expulsarse a sí
	# mismo no tiene sentido — el servidor ya lo rechaza igual, ver
	# GestorGrupos._pedir_expulsar_red, esto es solo prolijidad de UI).
	if soy_lider and str(miembro.get("id_unico", "")) != id_lider:
		var id_objetivo: String = str(miembro.get("id_unico", ""))
		var boton_expulsar := Button.new()
		boton_expulsar.text = "Expulsar"
		boton_expulsar.pressed.connect(func() -> void: GestorGrupos.expulsar(id_objetivo))
		fila.add_child(boton_expulsar)

	return fila
