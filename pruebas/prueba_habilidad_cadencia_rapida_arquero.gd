# =============================================================================
# Prueba de HabilidadCadenciaRapidaArquero: al activarla, divide entre
# multiplicador_cadencia TANTO la duracion_recuperacion de la AccionAtacar
# COMO la duracion_pose_ataque de HabilidadFlecha (las dos — apurar solo la
# recuperación dejaba el efecto casi imperceptible, ver el comentario de
# esa clase) y muestra un ícono de estado sobre el mob (vía BuffsComponente)
# mientras dure. Al llamar desactivar() antes de tiempo (lo que hace
# EnemigoEsqueletoArquero._decidir_reaccion al elegir retirada en vez de
# cadencia — cada ventana de 5s es independiente de la anterior) o al
# vencer sola, vuelve a la duracion_recuperacion normal y se quita el
# ícono — mismo mecanismo de reevaluación continua contra un timestamp
# que ya usa HabilidadFervor (no un temporizador de un solo disparo).
#
# Usa PlaceholderTexture2D como ícono (no hay arte propio todavía — ver
# HabilidadCadenciaRapidaArquero.icono_buff, queda como @export para que
# el usuario asigne uno real desde el Inspector) — alcanza para probar que
# BuffsComponente.esta_activo() se prende y apaga en el momento correcto,
# sin depender de qué textura sea.
#
# Llama activar()/desactivar() directo en vez de pasar por _decidir_
# reaccion: prueba justo la habilidad en sí, ajeno a la moneda 50/50 de la
# IA que la dispara.
#   godot --headless --path . --script res://pruebas/prueba_habilidad_cadencia_rapida_arquero.gd
# =============================================================================
extends SceneTree

var _jugador
var _mob
var _habilidad
var _accion_atacar
var _habilidad_flecha
var _duracion_normal: float
var _duracion_pose_normal: float
var _fase := 0
var _contador := 0

var _resultados: Array[bool] = []
var _ok_icono_configurado_en_escena := false


func _process(_delta: float) -> bool:
	if _fase > 0 and _habilidad == null:
		# Falla rápido y con mensaje claro en vez de quedarse llamando a
		# null cada fotograma para siempre (silencioso, sin cortar nunca)
		# si la clase nueva no llegó a registrarse — hace falta un
		# "--import" antes de correr --script la primera vez que se agrega
		# un class_name nuevo referenciado como TIPO estático desde otro
		# script (ver EnemigoEsqueletoArquero.gd).
		push_error("_habilidad_cadencia_rapida es null — ¿faltó reimportar (--headless --import) tras crear HabilidadCadenciaRapidaArquero?")
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
			_verificar(true, "Al activar: baja duracion_recuperacion y aparece el ícono")
			_habilidad.desactivar()
			_fase = 3
		3:
			_verificar(false, "Tras desactivar() antes de tiempo: vuelve a lo normal y se quita el ícono")
			_habilidad.activar()
			_contador = 0
			_fase = 4
		4:
			_contador += 1
			if _contador < 40:  # ~0.66s: pasado duracion=0.5s, ya debería haber vencido sola.
				return false
			_verificar(false, "Pasada la duración: vence sola, vuelve a lo normal y sin ícono")
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoEsqueletoArquero.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2(300, 0)

	_habilidad = _mob._habilidad_cadencia_rapida
	if _habilidad == null:
		return  # el guard de _process() corta acá, con mensaje, en el próximo fotograma.
	# Configurado tal cual queda en la escena, ANTES de pisarlo para el
	# resto de la prueba: icono_buff sin asignar fue justo el bug
	# reportado por el usuario ("no le sale el ícono") — sin este chequeo,
	# la prueba pasaba igual aunque nadie hubiera puesto ningún ícono real.
	_ok_icono_configurado_en_escena = _habilidad.icono_buff != null
	print("icono_buff viene configurado en la escena (esperado true): %s" % _ok_icono_configurado_en_escena)
	_habilidad.icono_buff = PlaceholderTexture2D.new()
	_habilidad.duracion = 0.5  # acorta la espera de la prueba (el real, en el .tscn, es 5.0s).
	_accion_atacar = _mob.get_node("ArbolComportamiento/Selector/Atacar")
	_duracion_normal = _accion_atacar.duracion_recuperacion
	_habilidad_flecha = _mob.get_node("Habilidades/HabilidadFlecha")
	_duracion_pose_normal = _habilidad_flecha.duracion_pose_ataque


func _verificar(debe_estar_activa: bool, etiqueta: String) -> void:
	var duracion_esperada: float = (_duracion_normal / _habilidad.multiplicador_cadencia) if debe_estar_activa else _duracion_normal
	var pose_esperada: float = (_duracion_pose_normal / _habilidad.multiplicador_cadencia) if debe_estar_activa else _duracion_pose_normal
	var duracion_ok := absf(_accion_atacar.duracion_recuperacion - duracion_esperada) < 0.001
	var pose_ok := absf(_habilidad_flecha.duracion_pose_ataque - pose_esperada) < 0.001
	var buffs := _mob.get_node_or_null("BuffsComponente") as BuffsComponente
	var icono_activo := buffs != null and buffs.esta_activo("cadencia_rapida")
	var ok := duracion_ok and pose_ok and icono_activo == debe_estar_activa
	_resultados.append(ok)
	print("%s (esperado true): %s (duracion_recuperacion=%.2f, duracion_pose_ataque=%.2f, ícono activo=%s)" % [
		etiqueta, ok, _accion_atacar.duracion_recuperacion, _habilidad_flecha.duracion_pose_ataque, icono_activo
	])


func _informar() -> bool:
	var exito := _ok_icono_configurado_en_escena
	for r in _resultados:
		exito = exito and r
	print("PRUEBA HABILIDAD CADENCIA RÁPIDA ARQUERO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
