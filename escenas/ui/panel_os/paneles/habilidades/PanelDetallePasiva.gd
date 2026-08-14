extends Panel
## Detalle de UNA pasiva seleccionada en la pestaña "Pasivas" de
## PanelHabilidades — mucho más simple que PanelDetalleHabilidad (sin
## nivel/costo/estadísticas de combate: las pasivas no se equipan, solo se
## ven). Reemplaza el tooltip que tenía ItemPasiva antes — pedido del
## usuario: "como el juego es móvil no me sirve la descripción como
## tooltip, quiero que al seleccionarla salga la descripción en el panel
## de detalles". El botón "Mejorar" (gastar puntos, ver MejorasComponente)
## solo se muestra para pasivas de ESTADÍSTICA — las de gatillo no tienen
## niveles que comprar.

@onready var icon := $MarginContainer/VBoxContainer/HBoxContainer/TextureRect
@onready var name_label := $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/EtiquetaNombre
@onready var description_label := $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenDescripcion/VBoxDescripcion/EtiquetaDescripcion
@onready var _titulo_actuales: Label = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenDescripcion/VBoxDescripcion/EtiquetaTituloActuales
@onready var _lista_actuales: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenDescripcion/VBoxDescripcion/ListaEfectosActuales
@onready var _titulo_proximo: Label = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenDescripcion/VBoxDescripcion/EtiquetaTituloProximo
@onready var _lista_proximo: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/MargenDescripcion/VBoxDescripcion/ListaEfectosProximo
@onready var _fila_mejorar: HBoxContainer = $MarginContainer/VBoxContainer/HBoxMejorar
@onready var _nivel_mejora_label: Label = $MarginContainer/VBoxContainer/HBoxMejorar/EtiquetaNivelMejora
@onready var _contenedor_puntos_mejora: HBoxContainer = $MarginContainer/VBoxContainer/HBoxMejorar/ContenedorPuntosMejora
@onready var _boton_mejorar: Button = $MarginContainer/VBoxContainer/HBoxMejorar/BotonMejorar

const _TEXTO_SIN_SELECCION := "Seleccioná una pasiva de la lista para ver su descripción."
const _TEXTO_SIN_PASIVAS := "Todavía no tenés ninguna pasiva desbloqueada."

## Mismo dorado que ya usa BarraXP (ver tema.tres) e IndicadorNivelMejora —
## el cuadrito junto a cada efecto reusa ese color en vez de uno nuevo.
const _COLOR_EFECTO := Color(0.72, 0.56, 0.08, 1)

## Campos de AtributosBase que se muestran con "%" en vez de plano — mismo
## criterio que PanelTablero.gd, para que el número coincida con el resto
## de la UI.
const _CAMPOS_PORCENTUALES := [
	"potencia", "probabilidad_critico", "dano_critico", "fortaleza",
	"resistencia_fisica", "resistencia_aire", "resistencia_agua",
	"resistencia_fuego", "resistencia_tierra", "regeneracion_vida",
]
## Nombre legible de cada campo de AtributosBase que una pasiva de stat
## puede otorgar — evita mostrar el nombre crudo de la variable (p. ej.
## "resistencia_fisica") en la descripción.
const _NOMBRES_CAMPOS := {
	"danos": "daño", "potencia": "potencia", "impacto": "impacto",
	"afliccion": "aflicción", "impulso": "impulso",
	"probabilidad_critico": "probabilidad de crítico", "dano_critico": "daño crítico",
	"regeneracion_vida": "regeneración de vida", "regeneracion_vida_plana": "regeneración de vida",
	"regeneracion_energia": "regeneración de energía", "defensa": "defensa",
	"tenacidad": "tenacidad", "fortaleza": "fortaleza",
	"resistencia_fisica": "resistencia física", "resistencia_aire": "resistencia de aire",
	"resistencia_agua": "resistencia de agua", "resistencia_fuego": "resistencia de fuego",
	"resistencia_tierra": "resistencia de tierra",
}

var _pasiva_actual: PasivaStatDesbloqueo = null
## Texto de descripción tal cual llega en show_pasiva() — solo se usa para
## pasivas de GATILLO (sin bono numérico); las de estadística lo
## reemplazan por completo con sus efectos en números.
var _descripcion_base: String = ""
var _indicador_puntos_mejora: Control = null


func _ready() -> void:
	_boton_mejorar.pressed.connect(_on_mejorar_pressed)
	# Gastar puntos en una HABILIDAD (otra pestaña) también cambia los
	# puntos disponibles acá — refrescar el botón (deshabilitado/no) sin
	# esperar a reseleccionar la fila.
	BusEventos.mejora_comprada.connect(func(_e, _t, _n): _actualizar_fila_mejorar(); _actualizar_descripcion())
	mostrar_sin_seleccion()


func mostrar_sin_seleccion() -> void:
	icon.texture = null
	name_label.text = ""
	description_label.text = _TEXTO_SIN_SELECCION
	description_label.visible = true
	_titulo_actuales.visible = false
	_lista_actuales.visible = false
	_titulo_proximo.visible = false
	_lista_proximo.visible = false
	_pasiva_actual = null
	_fila_mejorar.visible = false


func mostrar_sin_pasivas() -> void:
	icon.texture = null
	name_label.text = ""
	description_label.text = _TEXTO_SIN_PASIVAS
	description_label.visible = true
	_titulo_actuales.visible = false
	_lista_actuales.visible = false
	_titulo_proximo.visible = false
	_lista_proximo.visible = false
	_pasiva_actual = null
	_fila_mejorar.visible = false


func show_pasiva(nombre: String, descripcion: String, icono: Texture2D, pasiva_stat: PasivaStatDesbloqueo = null) -> void:
	icon.texture = icono
	name_label.text = nombre
	_descripcion_base = descripcion
	_pasiva_actual = pasiva_stat
	_actualizar_fila_mejorar()
	_actualizar_descripcion()


func _actualizar_fila_mejorar() -> void:
	if _pasiva_actual == null:
		_fila_mejorar.visible = false
		return
	_fila_mejorar.visible = true
	var tier: int = 0
	var mejoras := Utils.mejoras_componente_local()
	if mejoras:
		tier = mejoras.nivel_pasiva(_pasiva_actual.resource_path)

	if _indicador_puntos_mejora == null:
		_indicador_puntos_mejora = IndicadorNivelMejora.new()
		_contenedor_puntos_mejora.add_child(_indicador_puntos_mejora)
	# 1 + tier / 1 + max_niveles: mismo motivo que ItemPasiva._actualizar_
	# nivel — el desbloqueo ya da un tier gratis, el indicador arranca en
	# nivel 1, no en 0. "al_tope" de abajo sigue comparando el tier CRUDO
	# (sin el +1) contra max_niveles: eso es "cuántos tiers COMPRADOS con
	# puntos ya tengo", un cálculo aparte de cómo se muestra el nivel.
	_indicador_puntos_mejora.max_tier = 1 + _pasiva_actual.max_niveles
	_indicador_puntos_mejora.tier = 1 + tier

	var al_tope := tier >= _pasiva_actual.max_niveles
	var costo := _pasiva_actual.costo_puntos_por_nivel
	var sin_puntos := mejoras == null or mejoras.puntos_disponibles() < costo
	Utils.actualizar_boton_mejorar(_boton_mejorar, al_tope, sin_puntos, costo)


## Pasiva de ESTADÍSTICA: reemplaza la descripción de texto por los
## efectos posta, en números — pedido del usuario: "no quiero descripcion,
## solo ver los efectos", con "Efectos actuales" arriba y "Efectos en el
## siguiente nivel" abajo (oculto al tope, no hay nada más que mostrar).
## Pasiva de GATILLO (Instinto Vengador, Cosecha de Vida...): no tiene
## bono numérico ni niveles — ahí sí hace falta su descripción de texto,
## queda tal cual.
func _actualizar_descripcion() -> void:
	var es_stat := _pasiva_actual != null and _pasiva_actual.bono != null
	description_label.visible = not es_stat
	_titulo_actuales.visible = es_stat
	_lista_actuales.visible = es_stat
	if not es_stat:
		description_label.text = _descripcion_base
		_titulo_proximo.visible = false
		_lista_proximo.visible = false
		return

	var tier: int = 0
	var mejoras := Utils.mejoras_componente_local()
	if mejoras:
		tier = mejoras.nivel_pasiva(_pasiva_actual.resource_path)
	# El tier ya incluye el nivel gratis del desbloqueo automático (ver
	# ExperienciaComponente._aplicar_crecimiento_nivel) — el efecto real
	# aplicado es (1 + tiers comprados) veces el bono base.
	_llenar_lista_efectos(_lista_actuales, _describir_bono(_pasiva_actual.bono, 1 + tier))

	var hay_proximo := tier < _pasiva_actual.max_niveles
	_titulo_proximo.visible = hay_proximo
	_lista_proximo.visible = hay_proximo
	if hay_proximo:
		_llenar_lista_efectos(_lista_proximo, _describir_bono(_pasiva_actual.bono, 2 + tier))


## Un ícono (cuadrito de color) por línea de efecto — pedido del usuario
## (mismo criterio que las estadísticas de PanelDetalleHabilidad): antes
## era un bloque de texto plano sin nada que ayude a escanearlo rápido.
func _llenar_lista_efectos(contenedor: VBoxContainer, efectos: Array[String]) -> void:
	# free() INMEDIATO, no queue_free(): _on_mejorar_pressed() y el aviso
	# BusEventos.mejora_comprada (que MejorasComponente.gastar_en_pasiva
	# dispara en el mismo gasto) llaman a esto DOS VECES seguidas sin que
	# pase un fotograma entre medio — con queue_free() (diferido) la
	# segunda pasada encontraba las filas viejas todavía sin borrar y las
	# duplicaba en vez de reemplazarlas.
	for hijo in contenedor.get_children():
		hijo.free()
	if efectos.is_empty():
		var vacio := Label.new()
		vacio.text = "—"
		contenedor.add_child(vacio)
		return
	for texto in efectos:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		var cuadro := ColorRect.new()
		cuadro.custom_minimum_size = Vector2(8, 8)
		cuadro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cuadro.color = _COLOR_EFECTO
		var etiqueta := Label.new()
		etiqueta.text = texto
		fila.add_child(cuadro)
		fila.add_child(etiqueta)
		contenedor.add_child(fila)


## Lista de campos no-nulos de [bono] multiplicado por [factor] (cuántas
## veces se aplicó/se aplicaría), uno por línea — solo los que de verdad
## cambian algo, así una pasiva con un solo campo configurado (el caso de
## todas las actuales) no arrastra una lista larga de "+0" sin sentido.
func _describir_bono(bono: AtributosBase, factor: int) -> Array[String]:
	var partes: Array[String] = []
	for campo in _NOMBRES_CAMPOS:
		var valor: float = bono.get(campo) * factor
		if is_zero_approx(valor):
			continue
		var numero := str(int(valor)) if is_equal_approx(valor, roundf(valor)) else "%.1f" % valor
		var sufijo := "%" if campo in _CAMPOS_PORCENTUALES else ""
		partes.append("+%s%s %s" % [numero, sufijo, _NOMBRES_CAMPOS[campo]])
	return partes


func _on_mejorar_pressed() -> void:
	if _pasiva_actual == null:
		return
	var mejoras := Utils.mejoras_componente_local()
	if mejoras:
		mejoras.gastar_en_pasiva(_pasiva_actual.resource_path)
	_actualizar_fila_mejorar()
	_actualizar_descripcion()
