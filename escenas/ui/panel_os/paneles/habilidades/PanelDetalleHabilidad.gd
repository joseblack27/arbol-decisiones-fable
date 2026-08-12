extends Panel

@onready var icon              := $MarginContainer/VBoxContainer/HBoxContainer/TextureRect
@onready var name_label        := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FilaNombre/EtiquetaNombre
@onready var _etiqueta_equipada: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FilaNombre/EtiquetaEquipada
@onready var _nivel_personaje_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FilaNivelPersonaje/EtiquetaNivelPersonaje
@onready var _fila_nivel_mejora: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FilaNivelMejora
@onready var level_label       := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FilaNivelMejora/EtiquetaNivelMejora
@onready var _contenedor_puntos_mejora: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/FilaNivelMejora/ContenedorPuntosMejora
@onready var description_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenDescripcion/VBoxDescripcion/EtiquetaDescripcion
@onready var cost_label        := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenCosto/HBoxCosto/EtiquetaCosto
@onready var dmg_base_label    := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxDanoBase/EtiquetaDanoBase
@onready var dmg_calc_label    := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxDanoCalculado/EtiquetaDanoCalculado
@onready var type_damage_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxTipoDano/EtiquetaTipoDano
@onready var range_launch_label = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxRangoLanzamiento/EtiquetaRangoLanzamiento
## Cuadrito de color junto a "Tipo de daño" — el único que cambia de color
## en tiempo real (los demás quedan fijos en el .tscn), para que combine
## con el mismo color del elemento real (ver Enums.Habilidad.valor_color_dano).
@onready var _icono_tipo_dano: ColorRect = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenEstadisticas/VBoxEstadisticas/HBoxTipoDano/Icono
## Instancia única de IndicadorNivelMejora (ver ese script) — se crea la
## primera vez que hace falta y después solo se le actualiza tier/max_tier.
var _indicador_puntos_mejora: Control = null
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
@onready var _uplevel_btn: Button        = $MarginContainer/VBoxContainer/HBoxOpciones/MarginContainer/HBoxContainer/UpLevelButton
@onready var _overlay:     ColorRect     = $SuperposicionSlot
@onready var _selector:    SelectorSlot  = $SelectorSlot

var _skill_actual: DatosHabilidad = null


func _ready() -> void:
	_equip_btn.pressed.connect(_abrir_selector)
	_uplevel_btn.pressed.connect(_on_uplevel_pressed)
	_selector.slot_elegido.connect(_on_slot_elegido)
	_selector.cancelado.connect(_cerrar_selector)
	# El daño mostrado depende de los atributos actuales del jugador (bonos
	# de equipo incluidos) — recalcular cada vez que el equipo cambia, para
	# que si el panel está abierto no se quede mostrando un número viejo.
	BusEventos.equipo_cambiado.connect(_on_equipo_cambiado)
	# Gastar en OTRA habilidad (u otra pasiva) también cambia los puntos
	# disponibles — refrescar el botón/nivel mostrado sin reseleccionar.
	BusEventos.mejora_comprada.connect(func(_e, _t, _n): if _skill_actual: show_skill(_skill_actual))
	# Equipar esta MISMA habilidad (o moverla de slot) desde el selector
	# cambia si debe mostrarse como "equipada" — refrescar sin reseleccionar.
	BusEventos.habilidad_equipada.connect(func(_j, _i, _h): if _skill_actual: show_skill(_skill_actual))


## "Subir nivel" (ver MejorasComponente.gastar_en_habilidad) — el botón ya
## existía en el .tscn pero nunca se había cableado a nada.
func _on_uplevel_pressed() -> void:
	if not _skill_actual:
		return
	var mejoras := Utils.mejoras_componente_local()
	if mejoras:
		mejoras.gastar_en_habilidad(_skill_actual.resource_path)
	show_skill(_skill_actual)


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

	var slots := Utils.slot_habilidades_local()
	var equipada := false
	if slots:
		for i in slots.total_slots:
			var datos: DatosHabilidad = slots.obtener_datos(i)
			if datos and datos.resource_path == skill.resource_path:
				equipada = true
				break
	_etiqueta_equipada.visible = equipada

	var mejoras := Utils.mejoras_componente_local()
	var tier: int = mejoras.nivel_habilidad(skill.resource_path) if mejoras else 0
	var nivel_mejora := 1 + tier

	# "Nivel de personaje" es el requisito de catálogo (para EQUIPAR esta
	# habilidad, ver DatosHabilidad.nivel) — "Nivel de mejora" es el nivel
	# comprado con puntos (ver MejorasComponente/HabilidadBase.aplicar_
	# nivel_mejora), progreso independiente del jugador — antes iban
	# mezclados en una sola línea ("Nivel 1 — mejora 2/5") que confundía
	# los dos conceptos (reportado por el usuario). La fila de mejora
	# SIEMPRE queda visible, con o sin escalado, para no dejar un hueco de
	# altura distinta según la habilidad.
	_nivel_personaje_label.text = str(skill.level)
	_fila_nivel_mejora.visible = true

	# Costo/tope salen de skill.escalado (ver DatosHabilidad.escalado) —
	# sin escalado configurado esta habilidad todavía no es mejorable, así
	# que el botón se esconde entero en vez de mostrarse permanentemente
	# deshabilitado (sí queda a la vista que "no está disponible todavía").
	if skill.escalado:
		level_label.text = "%d/%d" % [nivel_mejora, skill.escalado.nivel_maximo]
		if _indicador_puntos_mejora == null:
			_indicador_puntos_mejora = IndicadorNivelMejora.new()
			_contenedor_puntos_mejora.add_child(_indicador_puntos_mejora)
		_indicador_puntos_mejora.max_tier = skill.escalado.nivel_maximo
		_indicador_puntos_mejora.tier = nivel_mejora
		_contenedor_puntos_mejora.visible = true

		var al_tope := nivel_mejora >= skill.escalado.nivel_maximo
		var costo := skill.escalado.costo_puntos_por_nivel
		var sin_puntos := mejoras == null or mejoras.puntos_disponibles() < costo
		Utils.actualizar_boton_mejorar(_uplevel_btn, al_tope, sin_puntos, costo)
		_uplevel_btn.visible = true
	else:
		level_label.text = "no disponible todavía"
		_contenedor_puntos_mejora.visible = false
		_uplevel_btn.visible = false

	var es_ataque := skill.categoria == Enums.Habilidad.Categoria.ATAQUE
	for fila in _filas_de_dano:
		fila.visible = es_ataque
	_fila_rango.visible = skill.range_meters > 0

	# Estadísticas YA AJUSTADAS por el nivel de mejora comprado (ver
	# EscaladoHabilidad.valor_para_campo) — antes este panel mostraba
	# siempre los valores de FÁBRICA (nivel 1) sin importar cuánto se
	# hubiera invertido en la habilidad (reportado: "no se ve afectado por
	# la subida de nivel"). skill.escalado == null (habilidad no
	# mejorable, o campo no configurado en ella) deja el valor base tal
	# cual. RANGO/RECARGA se calculan en las mismas unidades que ya usa el
	# panel (metros/segundos) — válido mientras el escalado de esos dos
	# campos sea porcentual (invariante de unidad); una tabla exacta de
	# valores para RANGO tendría que estar en metros para que esto siga
	# siendo correcto.
	var dano_min_mostrado := skill.damage_base_min
	var dano_max_mostrado := skill.damage_base_max
	var rango_mostrado := skill.range_meters
	var enfriamiento_mostrado := skill.cooldown_seconds
	if skill.escalado:
		dano_min_mostrado = int(skill.escalado.valor_para_campo(Enums.Habilidad.CampoEscalable.DANO_MIN, nivel_mejora, skill.damage_base_min))
		dano_max_mostrado = int(skill.escalado.valor_para_campo(Enums.Habilidad.CampoEscalable.DANO_MAX, nivel_mejora, skill.damage_base_max))
		rango_mostrado = int(skill.escalado.valor_para_campo(Enums.Habilidad.CampoEscalable.RANGO, nivel_mejora, skill.range_meters))
		enfriamiento_mostrado = skill.escalado.valor_para_campo(Enums.Habilidad.CampoEscalable.RECARGA, nivel_mejora, skill.cooldown_seconds)

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
		# Sin esto, los campos leídos más abajo (bono_dano, reduccion,
		# bono_potencia...) siempre mostraban el valor de FÁBRICA (nivel 1),
		# sin importar el nivel de mejora comprado — a diferencia de Daño/
		# Rango/Recarga (ver dano_min_mostrado arriba), que sí ya pasaban
		# por skill.escalado.valor_para_campo(). Mismo orden que usa
		# SlotHabilidades._instanciar() en el juego real. instantiate() sin
		# add_child no dispara _ready() (ver comentario más abajo), así que
		# esto no tiene efectos secundarios sobre nada más.
		tmp.aplicar_datos(skill)
		if skill.escalado:
			tmp.preparar_escalado(skill.escalado)
			tmp.aplicar_nivel_mejora(nivel_mejora)
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
		elif "duracion_camuflaje" in tmp:
			valores_descripcion["duracion"] = "%d" % int(tmp.get("duracion_camuflaje"))
		elif "duracion_inmunidad" in tmp:
			valores_descripcion["duracion"] = "%.1f" % tmp.get("duracion_inmunidad")
		elif "duracion_fervor" in tmp:
			valores_descripcion["duracion"] = "%d" % int(tmp.get("duracion_fervor"))
		elif "duracion_aturdimiento" in tmp:
			valores_descripcion["duracion"] = "%.1f" % tmp.get("duracion_aturdimiento")
		elif "duracion_acumulacion" in tmp:
			valores_descripcion["duracion"] = "%d" % int(tmp.get("duracion_acumulacion"))

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
		elif "porcentaje_detonacion" in tmp:
			valores_descripcion["valor1"] = "%d%%" % int(tmp.get("porcentaje_detonacion") * 100.0)
		elif "escena_proyectil" in tmp and tmp.get("escena_proyectil") != null:
			# Inmovilizar: la duración real vive dos escenas más adentro
			# (HabilidadProyectil.escena_proyectil -> Proyectil.escena_al_
			# impactar -> EfectoAreaBase.duracion) — nada raro, es la misma
			# cadena que ya arma HabilidadProyectilInmovilizador.tscn.
			var proy := (tmp.get("escena_proyectil") as PackedScene).instantiate()
			if "escena_al_impactar" in proy and proy.get("escena_al_impactar") != null:
				var efecto := (proy.get("escena_al_impactar") as PackedScene).instantiate()
				# Marca Detonable: EfectoMarcar hereda "duracion" de
				# EfectoAreaBase, pero ese campo es cuánto tiempo se queda
				# detectando cuerpos la zona de IMPACTO (0.4s, un detalle
				# interno) — nada que ver con duracion_marca, la cuenta
				# atrás real de la marca que el texto necesita mostrar. Hay
				# que preguntar por el nombre específico antes que por el
				# genérico heredado, o cualquier EfectoArea futuro con este
				# mismo choque de nombres se rompe igual.
				if "duracion_marca" in efecto:
					valores_descripcion["duracion"] = "%d" % int(efecto.get("duracion_marca"))
				elif "duracion" in efecto:
					valores_descripcion["duracion"] = "%.1f" % efecto.get("duracion")
				if "porcentaje_detonacion" in efecto:
					valores_descripcion["valor1"] = "%d%%" % int(efecto.get("porcentaje_detonacion") * 100.0)
				efecto.free()
			proy.free()

		# HabilidadSacrificio: a diferencia de las de arriba (un solo valor
		# dinámico, {valor1}), acá son TRES campos propios escalando juntos
		# — cada uno con su propio chequeo (no elif) porque los tres pueden
		# estar presentes a la vez en la misma habilidad.
		if "bono_potencia" in tmp:
			valores_descripcion["valor1"] = "%d" % int(tmp.get("bono_potencia"))
		if "bono_probabilidad_critico" in tmp:
			valores_descripcion["valor2"] = "%d" % int(tmp.get("bono_probabilidad_critico"))
		if "bono_dano_critico" in tmp:
			valores_descripcion["valor3"] = "%d" % int(tmp.get("bono_dano_critico"))
		tmp.free()

	var rango_calc := AtributosComponente.calcular_rango_con_factor(
		atributos, dano_min_mostrado, dano_max_mostrado, factor)
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

	dmg_base_label.text = "%d - %d" % [dano_min_mostrado, dano_max_mostrado]
	dmg_calc_label.text = dmg_calc

	# El cuadrito de "Tipo de daño" usa el MISMO color que ya pinta el
	# número de daño de arriba — un ícono por estadística (pedido del
	# usuario), y este en particular es tan literal como se puede: es el
	# color real del elemento, no uno inventado.
	_icono_tipo_dano.color = Color(color_dano)
	type_damage_label.text  = Utils.snake_to_pascal(Enums.Habilidad.TipoDano.keys()[skill.type_damage])
	range_launch_label.text = "%d metros" % rango_mostrado
	cool_down_label.text    = "%.1f segundos" % enfriamiento_mostrado
