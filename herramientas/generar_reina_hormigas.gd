# =============================================================================
# generar_reina_hormigas.gd — construye EnemigoReinaHormigas.tscn a partir
# de EnemigoHormigaSoldado.tscn (ya trae el esqueleto de animación
# MORDIDA_PREPARACION/MORDIDA_DASH que la Embestida de la reina reutiliza
# sin cambios, más un HabilidadCarga ya cableado con su componente_movimiento
# — ver EnemigoReinaHormigas.gd para el porqué de reusar esa animación).
#
# DOS PASADAS, cada una con la técnica correcta para lo que toca:
#
#   PASO A — texto plano (igual que generar_hormigas_reskin.gd): cambia el
#   script de la RAÍZ. set_script() sobre un nodo ya instanciado resetea los
#   @export de tipo nodo resueltos por node_paths= al cargar (confirmado en
#   la práctica con el mismo bug al reskinear las hormigas) — editar el
#   texto del .tscn evita el problema de raíz.
#
#   PASO B — instantiate()+add_child()+pack() (igual que poblar_nivel_
#   hormiguero.gd): TODO lo demás son nodos NUEVOS (con su propio script
#   nuevo) o propiedades planas sobre nodos existentes — nunca un set_script()
#   sobre un nodo ya presente, así que no hay node_paths que romper.
#   godot --headless --path . --script res://herramientas/generar_reina_hormigas.gd
# =============================================================================
extends SceneTree

const RUTA_BASE := "res://escenas/enemigos/EnemigoHormigaSoldado.tscn"
const RUTA_SALIDA := "res://escenas/enemigos/EnemigoReinaHormigas.tscn"


func _initialize() -> void:
	if not _reskin_texto():
		quit(1)
		return
	_aumentar_escena()
	quit(0)


# =============================================================================
# PASO A — texto plano
# =============================================================================
func _reskin_texto() -> bool:
	var archivo := FileAccess.open(RUTA_BASE, FileAccess.READ)
	if archivo == null:
		push_error("No se pudo abrir %s (error %d)." % [RUTA_BASE, FileAccess.get_open_error()])
		return false
	var texto := archivo.get_as_text()
	archivo.close()

	var patron := RegEx.new()
	patron.compile('\\[ext_resource type="Script"( uid="uid://[a-z0-9]+")? path="res://escenas/enemigos/EnemigoHormigaSoldado.gd"')
	var coincidencias := patron.search_all(texto)
	if coincidencias.size() != 1:
		push_error("Esperaba 1 ext_resource de script, encontré %d." % coincidencias.size())
		return false
	texto = patron.sub(texto, '[ext_resource type="Script" path="res://escenas/enemigos/EnemigoReinaHormigas.gd"')

	texto = _reemplazar_unico(texto,
		'path="res://recursos/enemigos/HormigaSoldado.tres" id="0_datos"',
		'path="res://recursos/enemigos/ReinaHormigas.tres" id="0_datos"')
	if texto == "":
		return false

	texto = _reemplazar_unico(texto,
		'[node name="EnemigoHormigaSoldado" type="CharacterBody2D"',
		'[node name="EnemigoReinaHormigas" type="CharacterBody2D"')
	if texto == "":
		return false

	var salida := FileAccess.open(RUTA_SALIDA, FileAccess.WRITE)
	if salida == null:
		push_error("No se pudo abrir %s para escribir (error %d)." % [RUTA_SALIDA, FileAccess.get_open_error()])
		return false
	salida.store_string(texto)
	salida.close()
	print("Paso A: %s escrito (script/datos/nombre propios)." % RUTA_SALIDA)
	return true


func _reemplazar_unico(texto: String, buscado: String, nuevo: String) -> String:
	var veces := texto.count(buscado)
	if veces != 1:
		push_error("Esperaba 1 ocurrencia de '%s', encontré %d." % [buscado, veces])
		return ""
	return texto.replace(buscado, nuevo)


# =============================================================================
# PASO B — instantiate + add_child/set + pack (solo nodos nuevos o
# propiedades planas sobre nodos existentes, nunca set_script() en un nodo
# ya presente).
# =============================================================================
func _aumentar_escena() -> void:
	var reina := (load(RUTA_SALIDA) as PackedScene).instantiate()

	# ── Cuerpo más grande que una hormiga rasa (mismo criterio visual que
	# los 3 jefes de la Mina: radios de colisión/vida en 32-34, no el 15-24
	# de una obrera/soldado) ─────────────────────────────────────────────
	var col := reina.get_node("CollisionShape2D").shape as CircleShape2D
	col.radius = 34.0
	var col_vida := reina.get_node("VidaComponente/CollisionShape2D").shape as CircleShape2D
	col_vida.radius = 34.0
	var sprite := reina.get_node("Sprite2D") as Sprite2D
	sprite.scale = Vector2(2.3, 2.3)

	# ── Atributos propios de jefa (mismo orden de magnitud que Forja/
	# Cristal/Corrupción: defensa ~18-20, fortaleza ~20-22) ──────────────
	var atributos := reina.get_node("AtributosComponente")
	var base := AtributosBase.new()
	base.defensa = 20.0
	base.fortaleza = 22.0
	atributos.base = base

	# ── Botín: vacío por ahora (se completa en el paso de loot del plan,
	# no reusar el de un Soldado raso) ────────────────────────────────────
	reina.tabla_botin = [] as Array[LootDrop]
	reina.xp_otorgada = 1000
	reina.mostrar_nombre = false
	reina.altura_nombre = -120.0

	# ── Wiring de los HabilidadBT nuevos (ver EnemigoReinaHormigas.gd) ──
	reina.habilidad_escupitajo_bt = load("res://componentes/arbol_comportamiento/recursos/EscupitajoAcidoReina.tres")
	reina.habilidad_llamada_auxilio_bt = load("res://componentes/arbol_comportamiento/recursos/LlamadaAuxilioReina.tres")
	reina.habilidad_embestida_bt = load("res://componentes/arbol_comportamiento/recursos/EmbestidaReina.tres")

	# ── Un jefe no huye: quitar la rama "Huir si vida baja" heredada del
	# Soldado (ver Enemigo.gd/EnfriamientoHuida) ─────────────────────────
	var selector := reina.get_node("ArbolComportamiento/Selector")
	var huida := selector.get_node_or_null("SecuenciaHuida")
	if huida:
		selector.remove_child(huida)
		huida.queue_free()

	# ── Kit inicial (fase 1): solo Mordida — el resto se agrega por fase
	# en tiempo de ejecución (ver _reanudar_fase) ────────────────────────
	var selector_habilidades := reina.get_node("ArbolComportamiento/Selector/Atacar/SelectorHabilidades")
	var kit_inicial: Array[HabilidadBT] = [load("res://componentes/arbol_comportamiento/recursos/MordidaReina.tres")]
	selector_habilidades.habilidades = kit_inicial

	# ── Contenedor de habilidades: quitar lo heredado de Soldado que no
	# forma parte del kit de la reina, reconfigurar Carga como Embestida,
	# agregar Mordida/Escupitajo/Llamada de Auxilio/Golpe de Transición ──
	var habilidades := reina.get_node("Habilidades")
	for nombre in ["HabilidadProyectil", "HabilidadArañazo", "HabilidadParpadeo"]:
		var nodo := habilidades.get_node_or_null(nombre)
		if nodo:
			habilidades.remove_child(nodo)
			nodo.queue_free()

	var embestida := habilidades.get_node("HabilidadCarga")
	embestida.name = "HabilidadEmbestidaReina"
	embestida.tipo_dano = 0  # TIERRA — ver Enums.Habilidad.TipoDano
	embestida.duracion_preparacion = 0.7
	embestida.dano_carga = 55.0
	embestida.multiplicador_velocidad_carga = 5.0
	embestida.distancia_maxima_dash = 320.0
	embestida.duracion_recarga = 10.0
	embestida.costo_energia = 0.0
	embestida.congela_movimiento_en_red = false

	var mordida := Node.new()
	mordida.name = "HabilidadMordida"
	mordida.set_script(load("res://escenas/habilidades/golpe_basico/HabilidadGolpeBasico.gd"))
	habilidades.add_child(mordida)
	mordida.owner = reina
	mordida.duracion_recarga = 1.2
	mordida.tipo_dano = 0
	mordida.congela_movimiento_en_red = false

	var escupitajo := Node.new()
	escupitajo.name = "HabilidadEscupitajoAcido"
	escupitajo.set_script(load("res://escenas/habilidades/area_efecto/HabilidadAreaEfecto.gd"))
	habilidades.add_child(escupitajo)
	escupitajo.owner = reina
	escupitajo.radio_area = 90.0
	escupitajo.duracion_recarga = 5.0
	escupitajo.tipo_dano = 0
	escupitajo.congela_movimiento_en_red = false

	var llamada := Node.new()
	llamada.name = "HabilidadLlamadaAuxilio"
	llamada.set_script(load("res://escenas/habilidades/llamada_auxilio/HabilidadLlamadaAuxilio.gd"))
	habilidades.add_child(llamada)
	llamada.owner = reina
	llamada.duracion_recarga = 25.0
	llamada.congela_movimiento_en_red = false

	var golpe_transicion := Node.new()
	golpe_transicion.name = "HabilidadGolpeVerdaderoTransicion"
	golpe_transicion.set_script(load("res://escenas/habilidades/golpe_verdadero_guardian/HabilidadGolpeVerdaderoGuardian.gd"))
	habilidades.add_child(golpe_transicion)
	golpe_transicion.owner = reina
	golpe_transicion.ignora_defensa = true
	golpe_transicion.duracion_recarga = 0.5
	golpe_transicion.congela_movimiento_en_red = false

	# ── Etiquetas de jefa (mismo layout que EnemigoNucleoForja.tscn) ─────
	var nombre_jefe := Label.new()
	nombre_jefe.name = "NombreJefe"
	nombre_jefe.offset_left = -104.0
	nombre_jefe.offset_top = -134.0
	nombre_jefe.offset_right = 104.0
	nombre_jefe.offset_bottom = -115.0
	nombre_jefe.add_theme_color_override("font_color", Color(0.9, 0.55, 0.5, 0.95))
	nombre_jefe.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	nombre_jefe.add_theme_constant_override("outline_size", 2)
	nombre_jefe.add_theme_font_size_override("font_size", 8)
	nombre_jefe.text = "Nv.15 Reina de las Hormigas"
	nombre_jefe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre_jefe.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reina.add_child(nombre_jefe)
	nombre_jefe.owner = reina

	var etiqueta_habilidad := Label.new()
	etiqueta_habilidad.name = "EtiquetaHabilidad"
	etiqueta_habilidad.visible = false
	etiqueta_habilidad.offset_left = -104.0
	etiqueta_habilidad.offset_top = -160.0
	etiqueta_habilidad.offset_right = 104.0
	etiqueta_habilidad.offset_bottom = -135.0
	etiqueta_habilidad.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35, 1))
	etiqueta_habilidad.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	etiqueta_habilidad.add_theme_constant_override("outline_size", 5)
	etiqueta_habilidad.add_theme_font_size_override("font_size", 16)
	etiqueta_habilidad.text = "Habilidad"
	etiqueta_habilidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta_habilidad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reina.add_child(etiqueta_habilidad)
	etiqueta_habilidad.owner = reina

	var escena := PackedScene.new()
	if escena.pack(reina) != OK:
		push_error("No se pudo empaquetar %s." % RUTA_SALIDA)
		return
	if ResourceSaver.save(escena, RUTA_SALIDA) != OK:
		push_error("No se pudo guardar %s." % RUTA_SALIDA)
		return
	print("Paso B: %s aumentado con kit de jefa." % RUTA_SALIDA)
