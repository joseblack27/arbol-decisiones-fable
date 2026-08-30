# =============================================================================
# Prueba de HabilidadCorte — la "definitiva de counter" pedida por el
# usuario. Cubre las TRES mecánicas que no comparte con ninguna otra
# habilidad del juego, cada una con su plomería propia (ver HabilidadCorte
# .gd, ParryComponente.gd):
#
#   1. DAÑO VERDADERO: ignora defensa/fortaleza/resistencias del objetivo
#      ("sin importar qué buffos tenga encima"), pero NO la inmunidad total
#      ("a menos que sea inmunidad").
#   2. ZONA RECTANGULAR: pega a lo que está delante en la dirección
#      apuntada, no a lo que está detrás ni al costado.
#   3. PARRY DIRECCIONAL: para el daño de ÁREA que viene del lado del
#      corte o del suelo donde estás parado, pero NO un proyectil (a ese
#      hay que cortarlo en el aire, no se para), ni un área por la espalda.
#
# Más el corte de ataques enemigos en el aire (proyectil enemigo destruido,
# proyectil PROPIO intacto) y que se pueda lanzar estando aturdido.
#
# OJO con dos trampas de armado que ya costaron una vuelta acá:
#   - TODOS los cuerpos se crean en _montar() (fotograma 1) y recién se
#     golpea en el 5: un CharacterBody2D/Area2D recién agregado al árbol
#     todavía no está registrado en el espacio de física, así que una
#     consulta en el MISMO fotograma no encuentra nada — y una prueba que
#     espera "no recibió daño" pasaría por el motivo equivocado.
#   - Los proyectiles se piden por GestorPiscinas.obtener(), como en el
#     juego real: HabilidadCorte los busca por la lista de la piscina (ver
#     ahí el porqué), así que uno instanciado a mano nunca se cortaría.
#   godot --headless --path . --script res://pruebas/prueba_habilidad_corte.gd
# =============================================================================
extends SceneTree

const _RUTA_HABILIDAD := "res://escenas/habilidades/corte/HabilidadCorte.gd"
const _RUTA_PROYECTIL := "res://escenas/habilidades/flecha/ProyectilFlecha.tscn"

var _fotogramas := 0
var _jugador: CharacterBody2D
var _corte
var _mob_delante
var _mob_detras
var _mob_invulnerable
var _mob_aturdido
var _proyectil_enemigo
var _proyectil_propio

var _dano_ignora_defensa_ok := false
var _pega_solo_adelante_ok := false
var _inmunidad_gana_ok := false
var _parry_para_area_de_frente_ok := false
var _parry_no_para_proyectil_ok := false
var _parry_no_para_area_de_espalda_ok := false
var _parry_para_area_a_los_pies_ok := false
var _corta_proyectil_enemigo_ok := false
var _no_corta_proyectil_propio_ok := false
var _se_lanza_aturdido_ok := false
var _corta_proyectil_tardio_ok := false
var _no_corta_tras_cerrarse_ok := false
var _proyectil_tardio
var _proyectil_post_ventana


## Jugador con las DOS propiedades que HabilidadBase/Jugador consultan por
## duck typing para decidir si una habilidad puede lanzarse — sin script
## propio, Object.set("_bloqueos_control", 3) no crea nada y el aturdimiento
## de la prueba sería mentira.
static func _script_jugador() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var _bloqueos_control := 0
var _muerto := false
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_probar_dano_y_zona()
			_probar_inmunidad_total()
			_probar_parry()
			_probar_lanzar_aturdido()
			_probar_corte_de_proyectiles()
		8:
			# Un proyectil que aparece DENTRO del rectángulo varios
			# fotogramas después del lanzamiento: la ventana sigue abierta
			# (dura 1s), así que también tiene que cortarse.
			_lanzar_proyectil_tardio()
		12:
			# GestorPiscinas.liberar() apaga/esconde diferido — margen.
			_corta_proyectil_tardio_ok = not _proyectil_tardio.visible
			print("Corta un proyectil que entra DESPUÉS del lanzamiento (esperado true): %s" % \
				_corta_proyectil_tardio_ok)
			# Cerrar la ventana a mano y confirmar que ya no corta más:
			# sin esto, un bug de "la ventana nunca se cierra" pasaría
			# desapercibido y Corte sería un escudo permanente.
			_corte._ventana_restante = 0.0
			_lanzar_proyectil_post_ventana()
		16:
			_no_corta_tras_cerrarse_ok = _proyectil_post_ventana.visible
			print("Ya NO corta con la ventana cerrada (esperado true): %s" % _no_corta_tras_cerrarse_ok)
			return _informar()
	return false


func _proyectil_en(pos: Vector2, fuente: Node) -> Node:
	var piscinas := root.get_node("/root/GestorPiscinas")
	var proy = piscinas.obtener(load(_RUTA_PROYECTIL) as PackedScene)
	proy.global_position = pos
	proy.configurar(Vector2.LEFT, 1.0, 10.0, fuente, Enums.Habilidad.TipoDano.FISICO)
	return proy


func _lanzar_proyectil_tardio() -> void:
	_proyectil_tardio = _proyectil_en(Vector2(70, 0), _mob_delante)


func _lanzar_proyectil_post_ventana() -> void:
	_proyectil_post_ventana = _proyectil_en(Vector2(75, 0), _mob_delante)


## Mob de mentira con VidaComponente real (un Area2D CON su propia forma,
## igual que EnemigoRaton/EnemigoAraña — sin eso las consultas de física no
## lo encuentran) y, opcionalmente, AtributosComponente con mucha defensa y
## resistencia física: sin ignorar defensas, un corte de 30-40 contra 25 de
## defensa + 80% de reducción quedaría en el piso de 1 de daño.
func _crear_mob(pos: Vector2, con_defensa: bool) -> CharacterBody2D:
	var mob := CharacterBody2D.new()
	mob.add_to_group("enemigos")
	mob.collision_layer = 2
	root.add_child(mob)
	mob.global_position = pos

	var vida = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida.name = "VidaComponente"
	vida.salud_maxima = 500.0
	mob.add_child(vida)
	vida.salud_actual = 500.0
	var forma_vida := CollisionShape2D.new()
	var circ_vida := CircleShape2D.new()
	circ_vida.radius = 12.0
	forma_vida.shape = circ_vida
	vida.add_child(forma_vida)

	if con_defensa:
		var atrib = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
		atrib.name = "AtributosComponente"
		var base = (load("res://recursos/AtributosBase.gd") as GDScript).new()
		base.defensa = 25.0
		base.fortaleza = 40.0
		base.resistencia_fisica = 40.0
		atrib.base = base
		mob.add_child(atrib)
	return mob


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.set_script(_script_jugador())
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)
	current_scene = _jugador
	_jugador.global_position = Vector2.ZERO

	var vida_j = (load("res://componentes/VidaComponente.gd") as GDScript).new()
	vida_j.name = "VidaComponente"
	vida_j.salud_maxima = 200.0
	_jugador.add_child(vida_j)
	vida_j.salud_actual = 200.0

	_corte = (load(_RUTA_HABILIDAD) as GDScript).new()
	_corte.entidad_dueña = _jugador
	_jugador.add_child(_corte)

	# Todos acá (fotograma 1), no dentro de cada prueba — ver la cabecera.
	# El tajo apunta a la DERECHA y mide 160 px de largo por 70 de ancho.
	_mob_delante = _crear_mob(Vector2(100, 0), true)     # dentro
	_mob_detras = _crear_mob(Vector2(-100, 0), true)     # detrás, fuera
	_mob_invulnerable = _crear_mob(Vector2(60, 0), false)
	_mob_aturdido = _crear_mob(Vector2(130, 0), false)


func _vida(nodo: Node) -> float:
	return (nodo.get_node("VidaComponente") as VidaComponente).salud_actual


func _probar_dano_y_zona() -> void:
	# El invulnerable está en el camino desde el primer tajo — se vuelve
	# inmune ANTES de cualquier golpe para que su chequeo sea real.
	(_mob_invulnerable.get_node("VidaComponente") as VidaComponente).activar_invulnerabilidad(30.0)

	_corte._ejecutar(Vector2.RIGHT, 1.0)

	var perdida_delante := 500.0 - _vida(_mob_delante)
	_dano_ignora_defensa_ok = perdida_delante >= 30.0
	print("Corte ignora defensa y resistencias (esperado >= 30 de daño): %.1f" % perdida_delante)

	var perdida_detras := 500.0 - _vida(_mob_detras)
	_pega_solo_adelante_ok = perdida_detras == 0.0
	print("No toca al que está detrás, fuera del rectángulo (esperado 0.0): %.1f" % perdida_detras)


## La única excepción que el usuario sí quiso conservar: "a menos que sea
## inmunidad". La invulnerabilidad vive aguas abajo del pipeline, en
## VidaComponente.quitar_vida(), así que el daño verdadero no la pasa.
## Ojo: este mob YA recibió el tajo de _probar_dano_y_zona (está a 60 px,
## dentro del rectángulo) — que siga intacto es justo lo que se mide.
func _probar_inmunidad_total() -> void:
	_inmunidad_gana_ok = _vida(_mob_invulnerable) == 500.0
	print("La inmunidad total SÍ para el corte (esperado 500.0): %.1f" % _vida(_mob_invulnerable))


func _probar_parry() -> void:
	var vida_j := _jugador.get_node("VidaComponente") as VidaComponente

	# Corte hacia la DERECHA → guardia hacia la derecha.
	_corte._ejecutar(Vector2.RIGHT, 1.0)

	# (a) Daño de ÁREA desde la derecha (de frente al corte): parado.
	var antes := vida_j.salud_actual
	vida_j.quitar_vida(50.0, null, Enums.Habilidad.TipoDano.FISICO, false, true, Vector2(300, 0))
	_parry_para_area_de_frente_ok = vida_j.salud_actual == antes
	print("Parry para el daño de ÁREA que viene del lado del corte (esperado sin cambio): %.1f -> %.1f" % [
		antes, vida_j.salud_actual])

	# (b) Un PROYECTIL no se para: es_area=false (a ese hay que cortarlo).
	antes = vida_j.salud_actual
	vida_j.quitar_vida(10.0, null, Enums.Habilidad.TipoDano.FISICO, false)
	_parry_no_para_proyectil_ok = vida_j.salud_actual < antes
	print("El parry NO para un proyectil (esperado que baje): %.1f -> %.1f" % [antes, vida_j.salud_actual])

	# (c) Área por la ESPALDA (desde la izquierda): entra igual.
	antes = vida_j.salud_actual
	vida_j.quitar_vida(10.0, null, Enums.Habilidad.TipoDano.FISICO, false, true, Vector2(-300, 0))
	_parry_no_para_area_de_espalda_ok = vida_j.salud_actual < antes
	print("El parry NO cubre la espalda (esperado que baje): %.1f -> %.1f" % [antes, vida_j.salud_actual])

	# (d) "Encima": el charco a los pies, sin dirección de la cual venir.
	antes = vida_j.salud_actual
	vida_j.quitar_vida(10.0, null, Enums.Habilidad.TipoDano.FISICO, false, true, _jugador.global_position)
	_parry_para_area_a_los_pies_ok = vida_j.salud_actual == antes
	print("Parry para el área en la que estás PARADO ENCIMA (esperado sin cambio): %.1f -> %.1f" % [
		antes, vida_j.salud_actual])


## "Este ataque siempre debe estar disponible para lanzarse, sin importar
## si el jugador está en algún estado alterado" — se simula el aturdimiento
## con el mismo contador que usa EfectoAturdir (_bloqueos_control), y se
## entra por activar() (no _ejecutar directo) que es donde vive el chequeo.
func _probar_lanzar_aturdido() -> void:
	var antes := _vida(_mob_aturdido)
	_jugador._bloqueos_control = 3
	_corte._recarga_restante = 0.0
	_corte.activar(Vector2.RIGHT, 1.0)
	_se_lanza_aturdido_ok = _vida(_mob_aturdido) < antes
	print("Se lanza aunque el dueño esté aturdido (esperado que baje de %.1f): %.1f" % [
		antes, _vida(_mob_aturdido)])
	_jugador._bloqueos_control = 0


func _probar_corte_de_proyectiles() -> void:
	var escena := load(_RUTA_PROYECTIL) as PackedScene
	# El autoload por get_node() y no por su identificador global: en un
	# proceso --script fresco, resolverlo como identificador se pisa con el
	# orden de arranque (mismo artefacto de siempre en esta suite).
	var piscinas := root.get_node("/root/GestorPiscinas")

	# Por la PISCINA, como en el juego real (ver la cabecera).
	_proyectil_enemigo = piscinas.obtener(escena)
	_proyectil_enemigo.global_position = Vector2(80, 0)
	_proyectil_enemigo.configurar(Vector2.LEFT, 1.0, 10.0, _mob_delante, Enums.Habilidad.TipoDano.FISICO)

	# Propio: mismo lugar, pero lanzado por el jugador — no debe cortarse.
	_proyectil_propio = piscinas.obtener(escena)
	_proyectil_propio.global_position = Vector2(90, 0)
	_proyectil_propio.configurar(Vector2.RIGHT, 1.0, 10.0, _jugador, Enums.Habilidad.TipoDano.FISICO)

	_corte._ejecutar(Vector2.RIGHT, 1.0)

	# liberar() no destruye el nodo: lo esconde y lo apaga para reciclarlo,
	# así que "cortado" se mide por visible, no por is_instance_valid.
	_corta_proyectil_enemigo_ok = not _proyectil_enemigo.visible
	print("Corta el proyectil enemigo que le pasa por delante (esperado true): %s" % _corta_proyectil_enemigo_ok)

	_no_corta_proyectil_propio_ok = _proyectil_propio.visible
	print("NO corta el proyectil propio (esperado true): %s" % _no_corta_proyectil_propio_ok)


func _informar() -> bool:
	var exito := _dano_ignora_defensa_ok and _pega_solo_adelante_ok and _inmunidad_gana_ok \
		and _parry_para_area_de_frente_ok and _parry_no_para_proyectil_ok \
		and _parry_no_para_area_de_espalda_ok and _parry_para_area_a_los_pies_ok \
		and _corta_proyectil_enemigo_ok and _no_corta_proyectil_propio_ok \
		and _se_lanza_aturdido_ok and _corta_proyectil_tardio_ok \
		and _no_corta_tras_cerrarse_ok
	print("  daño verdadero (ignora defensa): %s" % _dano_ignora_defensa_ok)
	print("  zona rectangular solo hacia adelante: %s" % _pega_solo_adelante_ok)
	print("  la inmunidad total sigue ganando: %s" % _inmunidad_gana_ok)
	print("  parry para área de frente: %s" % _parry_para_area_de_frente_ok)
	print("  parry no para proyectiles: %s" % _parry_no_para_proyectil_ok)
	print("  parry no cubre la espalda: %s" % _parry_no_para_area_de_espalda_ok)
	print("  parry para el área a los pies: %s" % _parry_para_area_a_los_pies_ok)
	print("  corta proyectil enemigo: %s" % _corta_proyectil_enemigo_ok)
	print("  no corta proyectil propio: %s" % _no_corta_proyectil_propio_ok)
	print("  se lanza aturdido: %s" % _se_lanza_aturdido_ok)
	print("  corta un proyectil tardío (ventana abierta): %s" % _corta_proyectil_tardio_ok)
	print("  deja de cortar al cerrarse la ventana: %s" % _no_corta_tras_cerrarse_ok)
	print("PRUEBA HABILIDAD CORTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
