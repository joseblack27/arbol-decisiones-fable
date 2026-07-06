# =============================================================================
# DepuradorBT.gd  (Debug visual en juego)
#
# Panel visual que muestra el estado del árbol de comportamiento y la memoria
# en tiempo real, sin saturar la consola.
#
# CÓMO USARLO:
#   1. Añade un nodo DepuradorBT a la escena (como hijo del enemigo o de la raíz).
#   2. Asigna el ArbolComportamiento en el Inspector.
#   3. Ejecuta el juego — el panel aparece en pantalla.
#   4. Pulsa la tecla configurada (por defecto F1) para mostrar/ocultar.
#
# RECOMENDACIÓN:
#   Con este depurador activo puedes desactivar debug_activo en todos los
#   nodos del árbol. El panel centraliza toda la información visualmente.
# =============================================================================
class_name DepuradorBT
extends CanvasLayer

# ─── Configuración ─────────────────────────────────────────────────────────────
@export_group("Configuración")
## ArbolComportamiento a visualizar.
@export var arbol: ArbolComportamiento
## Muestra el panel lateral con los valores de la MemoriaBT.
@export var mostrar_memoria: bool = true
## Tecla para mostrar / ocultar el panel.
@export var tecla_toggle: Key = KEY_F1

@export_group("Posición y tamaño")
@export var posicion_arbol: Vector2   = Vector2(10, 10)
@export var posicion_memoria: Vector2 = Vector2(320, 10)
@export var ancho_panel_arbol: float   = 290.0
@export var ancho_panel_memoria: float = 250.0

# ─── Colores ───────────────────────────────────────────────────────────────────
const COLOR_EXITOSO     := Color(0.3, 0.9, 0.3)     # verde
const COLOR_FALLIDO     := Color(0.9, 0.3, 0.3)     # rojo
const COLOR_EN_EJECUCION := Color(0.95, 0.85, 0.2)  # amarillo
const COLOR_INACTIVO    := Color(0.5, 0.5, 0.5)     # gris
const COLOR_TITULO      := Color(0.4, 0.9, 1.0)     # cian
const COLOR_MEMORIA     := Color(0.9, 0.5, 1.0)     # magenta

const ICONO := {
	NodoBT.Estado.EXITOSO:      "✔",
	NodoBT.Estado.FALLIDO:      "✘",
	NodoBT.Estado.EN_EJECUCION: "●",
}

# ─── Nodos de UI ───────────────────────────────────────────────────────────────
var _panel_arbol:   PanelContainer
var _texto_arbol:   RichTextLabel
var _panel_memoria: PanelContainer
var _texto_memoria: RichTextLabel
var _label_titulo:  Label

var _visible_debug: bool = true
var _ticks: int = 0


# =============================================================================
# CICLO DE VIDA
# =============================================================================

func _ready() -> void:
	layer = 128  # Siempre encima de todo
	_construir_ui()

	if not arbol:
		push_warning("DepuradorBT: Asigna un ArbolComportamiento en el Inspector.")
		return

	# Se actualiza solo cuando el árbol hace un tick, no cada frame.
	arbol.arbol_actualizado.connect(_on_arbol_actualizado)

	var mem := arbol.obtener_memoria()
	if mem and mostrar_memoria:
		mem.variable_cambiada.connect(
			func(_n: String, _a: Variant, _v: Variant) -> void: _refrescar_memoria()
		)

	# Dibujo inicial.
	await get_tree().process_frame
	_refrescar_arbol()
	_refrescar_memoria()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == tecla_toggle:
			_visible_debug = not _visible_debug
			_panel_arbol.visible = _visible_debug
			if _panel_memoria:
				_panel_memoria.visible = _visible_debug and mostrar_memoria


# =============================================================================
# CONSTRUCCIÓN DE LA UI
# =============================================================================

func _construir_ui() -> void:
	_panel_arbol = _crear_panel(posicion_arbol, ancho_panel_arbol)
	var vbox_arbol := VBoxContainer.new()
	_panel_arbol.add_child(vbox_arbol)

	# — Cabecera del árbol —
	var cab_arbol := _crear_cabecera("◆  Árbol de Comportamiento", COLOR_TITULO)
	vbox_arbol.add_child(cab_arbol)

	var sep1 := HSeparator.new()
	vbox_arbol.add_child(sep1)

	_texto_arbol = _crear_rich_label(ancho_panel_arbol - 16.0)
	vbox_arbol.add_child(_texto_arbol)

	# — Panel memoria —
	if mostrar_memoria:
		_panel_memoria = _crear_panel(posicion_memoria, ancho_panel_memoria)
		var vbox_mem := VBoxContainer.new()
		_panel_memoria.add_child(vbox_mem)

		var cab_mem := _crear_cabecera("◆  MemoriaBT", COLOR_MEMORIA)
		vbox_mem.add_child(cab_mem)

		var sep2 := HSeparator.new()
		vbox_mem.add_child(sep2)

		_texto_memoria = _crear_rich_label(ancho_panel_memoria - 16.0)
		vbox_mem.add_child(_texto_memoria)

	# — Pie con tecla toggle —
	var hint := Label.new()
	hint.text = " [%s] mostrar/ocultar" % OS.get_keycode_string(tecla_toggle)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.position = posicion_arbol + Vector2(0, -16)
	add_child(hint)


func _crear_panel(pos: Vector2, ancho: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(ancho, 0.0)

	# Fondo semitransparente oscuro.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.88)
	style.border_color = Color(0.25, 0.25, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _crear_cabecera(texto: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	return lbl


func _crear_rich_label(ancho: float) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.custom_minimum_size = Vector2(ancho, 0.0)
	rtl.add_theme_font_size_override("normal_font_size", 11)
	return rtl


# =============================================================================
# ACTUALIZACIÓN DE CONTENIDO
# =============================================================================

func _on_arbol_actualizado(_estado: NodoBT.Estado) -> void:
	if not _visible_debug:
		return
	_ticks += 1
	_refrescar_arbol()

func _refrescar_arbol() -> void:
	if not arbol or not _texto_arbol:
		return

	var raiz = arbol._nodo_raiz
	if not raiz:
		_texto_arbol.text = "[color=gray]Sin nodo raíz[/color]"
		return

	var nombre_arbol := arbol.nombre_nodo
	var estado_raiz  = raiz.obtener_estado()
	var color_raiz   := _color_hex(estado_raiz)

	var sb := "[color=%s]%s[/color]  [color=gray]tick #%d[/color]\n" \
		% [color_raiz, nombre_arbol, _ticks]
	sb += _texto_nodo(raiz, "", true)

	_texto_arbol.text = sb


func _texto_nodo(nodo: NodoBT, prefijo: String, es_ultimo: bool) -> String:
	var estado  := nodo.obtener_estado()
	var tipo    = nodo.get_script().resource_path.get_file().get_basename() \
		if nodo.get_script() else "NodoBT"

	# Detectar si el nodo fue evaluado en el tick actual o es estado viejpo.
	var es_stale := nodo._ultimo_tick < arbol.tick_actual and arbol.tick_actual > 0
	var color: String
	var icono: String
	if es_stale:
		color = "#444444"   # gris oscuro — no evaluado este tick
		icono = "○"
	else:
		color = _color_hex(estado)
		icono = ICONO.get(estado, "○")

	var rama := "└─ " if es_ultimo else "├─ "
	var linea := "%s%s[color=%s]%s  %s[/color]  [color=#3a3a3a]%s[/color]\n" \
		% [prefijo, rama, color, icono, nodo.nombre_nodo, tipo]

	# Hijos NodoBT.
	var hijos: Array[NodoBT] = []
	for hijo in nodo.get_children():
		if hijo is NodoBT:
			hijos.append(hijo)

	# Prefijo para hijos: continuar línea vertical solo si hay más hermanos.
	var prefijo_hijos := prefijo + ("   " if es_ultimo else "│  ")
	for i in hijos.size():
		linea += _texto_nodo(hijos[i], prefijo_hijos, i == hijos.size() - 1)

	return linea


func _refrescar_memoria() -> void:
	if not mostrar_memoria or not _texto_memoria or not arbol:
		return

	var mem := arbol.obtener_memoria()
	if not mem:
		return

	var datos := mem.obtener_todos()
	if datos.is_empty():
		_texto_memoria.text = "[color=gray](vacía)[/color]"
		return

	var sb := ""
	for clave: String in datos:
		# Omitir claves internas del sistema BT.
		if clave.begins_with("__"):
			continue
		var valor: Variant = datos[clave]
		var color_val: String = _color_valor(valor)
		var val_str: String   = _formato_valor(valor)
		sb += "[color=#777777]%s[/color] [color=#444444]=[/color] [color=%s]%s[/color]\n" \
			% [clave, color_val, val_str]

	_texto_memoria.text = sb


# =============================================================================
# HELPERS
# =============================================================================

func _color_hex(estado: NodoBT.Estado) -> String:
	match estado:
		NodoBT.Estado.EXITOSO:       return "#4ddd4d"
		NodoBT.Estado.FALLIDO:       return "#dd4d4d"
		NodoBT.Estado.EN_EJECUCION:  return "#ddcc33"
	return "#777777"


func _color_valor(valor: Variant) -> String:
	if valor == null:               return "#555555"
	if valor is bool:               return "#4ddd4d" if valor else "#dd4d4d"
	if valor is float or valor is int: return "#66ccff"
	if valor is String:             return "#ffaa55"
	if valor is Vector2:            return "#bb88ff"
	return "#cccccc"


func _formato_valor(valor: Variant) -> String:
	if valor == null:               return "null"
	if valor is bool:               return "true" if valor else "false"
	if valor is float:              return "%.2f" % valor
	if valor is Vector2:            return "(%.1f, %.1f)" % [valor.x, valor.y]
	if valor is Object:
		return valor.name if valor.has_method("get_name") else valor.get_class()
	return str(valor)
