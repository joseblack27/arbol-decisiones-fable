# =============================================================================
# Prueba de HabilidadFuriaGuerrero: al activarla, aumenta velocidad_base
# (MovimientoComponente) un multiplicador_velocidad, suma bono_dano al
# daño del Arañazo, y multiplica multiplicador_recarga en TODAS las demás
# HabilidadBase hermanas bajo Habilidades/ (mismo mecanismo que ya usa
# EnemigoArañaReina._activar_furia_final, pero temporal acá) — y muestra
# un ícono de estado sobre el mob mientras dure. Al vencer, revierte los
# cuatro efectos solo y emite furia_terminada() — quien decide cuándo
# volver a intentar activarla (EnemigoCaballeroEsqueleto) depende de esa
# señal para su propia ventana de reintento.
#
# Usa PlaceholderTexture2D como ícono (no hay arte propio todavía — ver
# HabilidadFuriaGuerrero.icono_buff, queda como @export para que el
# usuario asigne uno real desde el Inspector).
#
# Llama activar() directo (no pasa por EnemigoCaballeroEsqueleto): prueba
# justo la habilidad en sí, ajeno a la moneda/temporizador de la IA que la
# dispara (esa parte se prueba aparte, ver prueba_caballero_furia_timing.gd).
#   godot --headless --path . --script res://pruebas/prueba_habilidad_furia_guerrero.gd
# =============================================================================
extends SceneTree

var _jugador
var _mob
var _habilidad
var _componente_movimiento
var _ataque_arañazo
var _habilidad_carga
var _velocidad_normal: float
var _dano_normal: float
var _fase := 0
var _contador := 0
var _veces_furia_terminada := 0

var _resultados: Array[bool] = []


func _process(_delta: float) -> bool:
	if _fase > 0 and _habilidad == null:
		# Falla rápido y con mensaje claro en vez de quedarse llamando a
		# null cada fotograma para siempre — ver memoria del proyecto
		# sobre class_name nuevos sin reimportar.
		push_error("_habilidad_furia es null — ¿faltó reimportar (--headless --import) tras crear HabilidadFuriaGuerrero?")
		quit(1)
		return true
	match _fase:
		0:
			_montar()
			_fase = 1
		1:
			_habilidad.activar()
			_fase = 2
		2:
			_verificar(true, "Al activar: sube velocidad/daño/recarga y aparece el ícono")
			_contador = 0
			_fase = 3
		3:
			_contador += 1
			if _contador < 40:  # ~0.66s: pasado duracion=0.5s, ya debería haber vencido sola.
				return false
			_verificar(false, "Pasada la duración: vence sola, revierte todo y sin ícono")
			var ok_señal := _veces_furia_terminada == 1
			_resultados.append(ok_señal)
			print("furia_terminada() se emitió exactamente una vez (esperado true): %s (%d veces)" % [
				ok_señal, _veces_furia_terminada
			])
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoCaballeroEsqueleto.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2(300, 0)

	_habilidad = _mob.get_node_or_null("Habilidades/HabilidadFuria")
	if _habilidad == null:
		return  # el guard de _process() corta acá, con mensaje, en el próximo fotograma.
	# Guarda de regresión: icono_buff viene configurado en la escena (mismo
	# hueco que ya pasó una vez con la cadencia rápida del arquero — quedó
	# sin asignar y nadie lo notó hasta que el usuario preguntó por qué no
	# aparecía ningún ícono). Se chequea ANTES de pisarlo con el placeholder
	# de acá abajo.
	var icono_de_escena_ok := _habilidad.icono_buff != null
	_resultados.append(icono_de_escena_ok)
	print("icono_buff viene configurado en la escena (esperado true): %s" % icono_de_escena_ok)
	_habilidad.furia_terminada.connect(func(): _veces_furia_terminada += 1)
	_habilidad.icono_buff = PlaceholderTexture2D.new()
	_habilidad.duracion = 0.5  # acorta la espera de la prueba (el real, en el .tscn, es 15.0s).

	_componente_movimiento = _mob.get_node("MovimientoComponente")
	_ataque_arañazo = _mob.get_node("Habilidades/HabilidadArañazo")
	_habilidad_carga = _mob.get_node("Habilidades/HabilidadCarga")
	_velocidad_normal = _componente_movimiento.velocidad_base
	_dano_normal = _ataque_arañazo.daño


func _verificar(debe_estar_activa: bool, etiqueta: String) -> void:
	var vel_esperada: float = (_velocidad_normal * _habilidad.multiplicador_velocidad) if debe_estar_activa else _velocidad_normal
	var dano_esperado: float = (_dano_normal + _habilidad.bono_dano) if debe_estar_activa else _dano_normal
	var recarga_esperada: float = _habilidad.multiplicador_recarga_habilidades if debe_estar_activa else 1.0

	var vel_ok := absf(_componente_movimiento.velocidad_base - vel_esperada) < 0.001
	var dano_ok := absf(_ataque_arañazo.daño - dano_esperado) < 0.001
	var recarga_ok := absf(_habilidad_carga.multiplicador_recarga - recarga_esperada) < 0.001
	var buffs := _mob.get_node_or_null("BuffsComponente") as BuffsComponente
	var icono_activo := buffs != null and buffs.esta_activo("furia")

	var ok := vel_ok and dano_ok and recarga_ok and icono_activo == debe_estar_activa
	_resultados.append(ok)
	print("%s (esperado true): %s (velocidad=%.1f, daño=%.1f, recarga_carga=%.2f, ícono activo=%s)" % [
		etiqueta, ok, _componente_movimiento.velocidad_base, _ataque_arañazo.daño,
		_habilidad_carga.multiplicador_recarga, icono_activo
	])


func _informar() -> bool:
	var exito := true
	for r in _resultados:
		exito = exito and r
	print("PRUEBA HABILIDAD FURIA GUERRERO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
