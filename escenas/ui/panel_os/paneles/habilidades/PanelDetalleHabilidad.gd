extends Panel

@onready var icon              := $MarginContainer/VBoxContainer/HBoxContainer/TextureRect
@onready var name_label        := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/EtiquetaNombre
@onready var level_label       := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/EtiquetaNivel
@onready var description_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenDescripcion/VBoxDescripcion/EtiquetaDescripcion
@onready var cost_label        := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenCosto/HBoxCosto/EtiquetaCosto
@onready var dmg_base_label    := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxDanoBase/EtiquetaDanoBase
@onready var dmg_calc_label    := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxDanoCalculado/EtiquetaDanoCalculado
@onready var type_damage_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxTipoDano/EtiquetaTipoDano
@onready var range_launch_label = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxRangoLanzamiento/EtiquetaRangoLanzamiento
## Filas de "solo tiene sentido si la habilidad ATACA" — se esconden como
## grupo para categorías que no atacan (defensa/potenciador/control, ver
## Enums.Habilidad.Categoria): mostraban "Daño: 0-0" en habilidades como
## Gancho o Grito de Guerra, que no significa nada (reportado por el
## usuario). HBoxEnfriamiento NO entra acá (aplica a cualquier categoría),
## y HBoxRangoLanzamiento TAMPOCO (ver _fila_rango más abajo): el rango
## también es relevante fuera de ATAQUE — Parpadeo (distancia del
## teletransporte) y Gancho (alcance del enganche, categoría CONTROL) SÍ
## tienen un rango real que mostrar aunque no ataquen.
@onready var _filas_de_dano: Array[Control] = [
	$MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxDanoBase,
	$MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxDanoCalculado,
	$MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxTipoDano,
]
## Fila de rango — visible cuando la habilidad DE VERDAD tiene un alcance
## (alcance_metros > 0), sin importar la categoría (ver comentario arriba).
@onready var _fila_rango: Control = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxRangoLanzamiento
@onready var cool_down_label    = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxEnfriamiento/EtiquetaEnfriamiento
@onready var _equip_btn:   Button        = $MarginContainer/VBoxContainer/HBoxOpciones/MarginContainer/HBoxContainer/BotonEquipar
@onready var _overlay:     ColorRect     = $SuperposicionSlot
@onready var _selector:    SelectorSlot  = $SelectorSlot

var _skill_actual: DatosHabilidad = null


func _ready() -> void:
	_equip_btn.pressed.connect(_abrir_selector)
	_selector.slot_elegido.connect(_on_slot_elegido)
	_selector.cancelado.connect(_cerrar_selector)
	# El daño mostrado depende de los atributos actuales del jugador (bonos
	# de equipo incluidos) — recalcular cada vez que el equipo cambia, para
	# que si el panel está abierto no se quede mostrando un número viejo.
	BusEventos.equipo_cambiado.connect(_on_equipo_cambiado)


func _on_equipo_cambiado(_equipados: Array) -> void:
	if _skill_actual:
		show_skill(_skill_actual)


## Atributos del jugador (bonos de equipo ya aplicados, ver
## AtributosComponente.recalcular_con_equipo) usados para mostrar el daño
## real que la habilidad va a infligir, no solo su rango base.
func _obtener_atributos_jugador() -> AtributosComponente:
	var jugador := Utils.jugador_local()
	if not jugador:
		return null
	return jugador.get_node_or_null("AtributosComponente") as AtributosComponente


# ── Selector ──────────────────────────────────────────────────────────────────

func _abrir_selector() -> void:
	if not _skill_actual or not _skill_actual.escena:
		return
	var slot_habs := Utils.slot_habilidades_local()
	_selector.setup(_skill_actual, slot_habs)
	_overlay.visible  = true
	_selector.visible = true


func _cerrar_selector() -> void:
	_overlay.visible  = false
	_selector.visible = false


func _on_slot_elegido(slot_index: int) -> void:
	var slot_habs := Utils.slot_habilidades_local()
	if slot_habs and _skill_actual:
		slot_habs.equipar(slot_index, _skill_actual)
	_cerrar_selector()


# ── Mostrar datos de la skill ─────────────────────────────────────────────────

func show_skill(skill: DatosHabilidad) -> void:
	if not skill:
		return
	_cerrar_selector()
	_skill_actual = skill

	icon.texture     = skill.icon
	name_label.text  = skill.name
	level_label.text = "Nivel %d" % skill.level

	var es_ataque := skill.categoria == Enums.Habilidad.Categoria.ATAQUE
	for fila in _filas_de_dano:
		fila.visible = es_ataque
	_fila_rango.visible = skill.range_meters > 0

	# "Daño Calculado" = dano_base + los atributos ofensivos ACTUALES del
	# jugador (bonus plano + potencia; el crítico no entra porque es un roll
	# aleatorio, no tiene sentido en un número fijo mostrado en pantalla),
	# escalado por el factor propio de la habilidad si tiene uno (ver
	# AtributosComponente.calcular_rango_con_factor — mismo helper que usa
	# HabilidadAura para la descripción de su buff, así los dos números
	# siempre coinciden). Sin AtributosComponente disponible, se muestra el
	# rango base tal cual.
	var atributos := _obtener_atributos_jugador()
	var factor := 1.0

	# Factor propio de la habilidad (p. ej. el lanzallamas solo aplica una
	# FRACCIÓN de esto por tick, ver HabilidadLanzallamas.multiplicador_
	# dano_tick — "decía 4-8 pero en realidad hace 1", reportado). Genérico
	# a propósito: se lee del script de la escena por nombre de propiedad,
	# así que cualquier habilidad futura con el mismo patrón se refleja acá
	# sola, sin tener que tocar este panel de nuevo. instantiate() sin
	# add_child no dispara _ready() — seguro leer y descartar.
	# Valores de descripción para habilidades que NO atacan (Escudo,
	# Curación, Grito de Guerra, Gancho, Inmovilizar): antes su magnitud y
	# duración estaban escritas A MANO en el texto de "descripcion" —
	# quedaban desincronizadas apenas alguien tocaba el export real sin
	# acordarse de actualizar también el .tres (pedido del usuario: que
	# salgan por parámetro, {valor1}/{duracion}, igual que {damage1} ya
	# sale del daño real calculado, no de un número pegado en el texto).
	# Mismo criterio "duck typing" que multiplicador_dano_tick de abajo:
	# se lee por nombre de propiedad conocido, primero el que exista.
	var valores_descripcion := {}

	if skill.escena:
		var tmp := skill.escena.instantiate()
		if "multiplicador_dano_tick" in tmp:
			factor = tmp.get("multiplicador_dano_tick")

		if "duracion_escudo" in tmp:
			valores_descripcion["duracion"] = "%d" % int(tmp.get("duracion_escudo"))
		elif "duracion_curacion" in tmp:
			valores_descripcion["duracion"] = "%d" % int(tmp.get("duracion_curacion"))
		elif "duracion_buff" in tmp:
			valores_descripcion["duracion"] = "%d" % int(tmp.get("duracion_buff"))
		elif "duracion_tiron" in tmp:
			valores_descripcion["duracion"] = "%.1f" % tmp.get("duracion_tiron")
		elif "duracion_invocacion" in tmp:
			valores_descripcion["duracion"] = "%d" % int(tmp.get("duracion_invocacion"))
		elif "duracion_vortice" in tmp:
			valores_descripcion["duracion"] = "%.1f" % tmp.get("duracion_vortice")

		if "cantidad_curacion" in tmp:
			valores_descripcion["valor1"] = "%d" % int(tmp.get("cantidad_curacion"))
		elif "bono_dano" in tmp:
			valores_descripcion["valor1"] = "%d" % int(tmp.get("bono_dano"))
		# HabilidadInvocacion: el daño del aliado invocado, no de la propia
		# habilidad (categoria POTENCIADOR, así que las filas de Daño quedan
		# escondidas — sin esto no había forma de ver cuánto pega el aliado,
		# reportado por el usuario: "no puedo ver el daño que hace").
		elif "dano_ataque" in tmp:
			valores_descripcion["valor1"] = "%d" % int(tmp.get("dano_ataque"))
		elif "reduccion" in tmp:
			valores_descripcion["valor1"] = "%d%%" % int(tmp.get("reduccion") * 100.0)
		elif "escena_proyectil" in tmp and tmp.get("escena_proyectil") != null:
			# Inmovilizar: la duración real vive dos escenas más adentro
			# (HabilidadProyectil.escena_proyectil -> Proyectil.escena_al_
			# impactar -> EfectoAreaBase.duracion) — nada raro, es la misma
			# cadena que ya arma HabilidadProyectilInmovilizador.tscn.
			var proy := (tmp.get("escena_proyectil") as PackedScene).instantiate()
			if "escena_al_impactar" in proy and proy.get("escena_al_impactar") != null:
				var efecto := (proy.get("escena_al_impactar") as PackedScene).instantiate()
				if "duracion" in efecto:
					valores_descripcion["duracion"] = "%.1f" % efecto.get("duracion")
				efecto.free()
			proy.free()
		tmp.free()

	var rango_calc := AtributosComponente.calcular_rango_con_factor(
		atributos, skill.damage_base_min, skill.damage_base_max, factor)
	var dmg_calc := "%d - %d" % [rango_calc.x, rango_calc.y]

	# El color del número de daño en la descripción sale del elemento real
	# de la habilidad (Enums.Habilidad.valor_color_dano), no de un
	# [color=...] pegado a mano en cada .tres — antes cada descripción
	# traía su propio color hardcodeado, y varios ya habían quedado
	# desincronizados del tipo_dano real (Ráfaga es AIRE pero se pintaba
	# con el cyan de AGUA; Golpe Básico/Carga/Muro son FÍSICO pero usaban
	# colores de otros elementos) — con esto es imposible que se
	# desincronicen, porque los dos salen del mismo dato.
	var color_dano: String = Enums.Habilidad.valor_color_dano[skill.type_damage]
	var dmg_calc_coloreado := "[color=%s][b]%s[/b][/color]" % [color_dano, dmg_calc]
	valores_descripcion["damage1"] = dmg_calc_coloreado
	description_label.text = skill.description.format(valores_descripcion)
	cost_label.text = str(skill.cost_energy)

	dmg_base_label.text = "%d - %d" % [skill.damage_base_min, skill.damage_base_max]
	dmg_calc_label.text = dmg_calc

	type_damage_label.text  = Utils.snake_to_pascal(Enums.Habilidad.TipoDano.keys()[skill.type_damage])
	range_launch_label.text = "%d metros" % skill.range_meters
	cool_down_label.text    = "%.1f segundos" % skill.cooldown_seconds
