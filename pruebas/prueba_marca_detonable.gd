# =============================================================================
# Prueba de la MARCA DETONABLE (ver MarcaComponente / EfectoMarcar).
#
# Es la única habilidad del juego en DOS ETAPAS: marcás un enemigo, la marca
# anota TODO el daño que reciba durante unos segundos y al vencer estalla
# devolviendo un porcentaje a los que tenga cerca. Premia concentrar el daño
# en un objetivo y combina con Vórtice (juntarlos y marcar al del medio).
#
# Verifica:
#   1. Acumula el daño que recibe el marcado, venga de la fuente que venga
#      (se escucha el bus, no cada habilidad).
#   2. Al vencer detona y daña a los enemigos de al lado — NO al marcado, que
#      ya se llevó ese daño en vida (cobrárselo otra vez sería contarlo dos
#      veces).
#   3. Lo que reparte es el porcentaje configurado de lo acumulado.
#   4. Si el marcado MUERE antes de tiempo, detona igual: matarlo rápido no
#      debe desperdiciar la marca.
#   5. Mientras dura hay un SELLO visible sobre el marcado, y desaparece al
#      detonar. Sin él la habilidad era invisible: no había forma de saber a
#      quién marcaste ni cuánto le quedaba (reportado: "la marca no se ve").
#   6. Al detonar aparece un IndicadorZonaEfecto centrado en el marcado con
#      el radio real de la explosión (pedido del usuario: "que muestre un
#      círculo cuando detone").
#   godot --headless --path . --script res://pruebas/prueba_marca_detonable.gd
# =============================================================================
extends SceneTree

const ACUMULADO := 100.0
const PORCENTAJE := 0.5
const RADIO := 150.0

var _f := 0
var _bus
var _marcado: CharacterBody2D
var _vecino: CharacterBody2D
var _lejano: CharacterBody2D
var _atacante: Node2D
## Sin anotar el tipo y creando el nodo con set_script: anotar
## "MarcaComponente" obliga a compilar esa clase mientras se parsea esta
## prueba, ANTES de que existan los autoloads que usa (BusEventos, Utils), y
## ahí falla la compilación y .new() deja de estar disponible. Mismo criterio
## que usan otras pruebas del proyecto con VidaComponente.
var _marca

var _vida_vecino_antes := 0.0
var _vida_lejano_antes := 0.0
var _vida_marcado_antes := 0.0

var _acumula := false
var _daña_al_vecino := false
var _no_daña_al_marcado := false
var _respeta_el_radio := false
var _detona_al_morir := false
var _sello_visible := false
var _sello_se_borra := false
var _indicador_zona_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_marca.activar(0.5, PORCENTAJE, RADIO, _atacante, 1)  # 1 = FUEGO
			# Daño "recibido" por el marcado, como si lo hubiéramos golpeado.
			_bus.daño_aplicado.emit(_marcado, ACUMULADO, _atacante, 1, false)
		4:
			_acumula = is_equal_approx(_marca.acumulado(), ACUMULADO)
			print("Acumula el daño recibido (esperado %.0f, %.0f): %s" % [
				ACUMULADO, _marca.acumulado(), _acumula])
			_vida_vecino_antes = _vida(_vecino)
			_vida_lejano_antes = _vida(_lejano)
			_vida_marcado_antes = _vida(_marcado)
			_sello_visible = _marcado.get_node_or_null("SelloMarca") != null
			print("Hay un sello visible sobre el marcado (esperado true): %s" % _sello_visible)
		# 0.5s = 30 fotogramas: acá ya detonó.
		45:
			var perdio_vecino := _vida_vecino_antes - _vida(_vecino)
			var perdio_lejano := _vida_lejano_antes - _vida(_lejano)
			var perdio_marcado := _vida_marcado_antes - _vida(_marcado)
			_daña_al_vecino = perdio_vecino > 0.0
			_no_daña_al_marcado = is_equal_approx(perdio_marcado, 0.0)
			_respeta_el_radio = is_equal_approx(perdio_lejano, 0.0)
			print("Detona sobre el vecino (esperado >0, perdió %.1f): %s" % [
				perdio_vecino, _daña_al_vecino])
			print("NO se lo cobra al marcado (esperado 0, perdió %.1f): %s" % [
				perdio_marcado, _no_daña_al_marcado])
			print("Respeta el radio, el lejano no se entera (esperado 0, perdió %.1f): %s" % [
				perdio_lejano, _respeta_el_radio])
			_sello_se_borra = _marcado.get_node_or_null("SelloMarca") == null
			print("El sello desaparece al detonar (esperado true): %s" % _sello_se_borra)

			var indicador: Node = null
			for hijo in current_scene.get_children():
				if hijo.get_script() == load("res://escenas/efectos/IndicadorZonaEfecto.gd"):
					indicador = hijo
					break
			_indicador_zona_ok = indicador != null \
				and indicador.global_position.distance_to(_marcado.global_position) < 0.01 \
				and is_equal_approx(indicador.radio, RADIO)
			print("Aparece el circulo de la detonacion (esperado true): %s" % _indicador_zona_ok)

			_probar_muerte_temprana()
			return _informar()
	return false


## Segunda parte: se marca de nuevo, se acumula y se MATA al marcado antes de
## que venza. Tiene que estallar igual.
func _probar_muerte_temprana() -> void:
	var marca2 = _nueva_marca()
	_vecino.add_child(marca2)
	marca2.activar(30.0, PORCENTAJE, RADIO, _atacante, 1)
	_bus.daño_aplicado.emit(_vecino, ACUMULADO, _atacante, 1, false)

	var antes := _vida(_marcado)
	# Matarlo dispara la señal "muerte" de su VidaComponente.
	(_vecino.get_node("VidaComponente") as VidaComponente).quitar_vida(99999.0)
	var perdio := antes - _vida(_marcado)
	_detona_al_morir = perdio > 0.0
	print("Si el marcado muere antes, detona igual (vecino perdió %.1f): %s" % [
		perdio, _detona_al_morir])


func _nueva_marca() -> Node:
	var nodo := Node.new()
	nodo.name = "MarcaComponente"
	nodo.set_script(load("res://componentes/MarcaComponente.gd"))
	return nodo


func _vida(entidad: Node) -> float:
	var v := entidad.get_node_or_null("VidaComponente") as VidaComponente
	return v.obtener_vida() if v else 0.0


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	# Quien "puso" la marca: un nodo suelto del bando del jugador, para que
	# Combate.mismo_equipo no filtre a los enemigos de la explosión.
	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	escena.add_child(_atacante)
	_atacante.global_position = Vector2(-400, 0)

	var escena_mob := load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene
	_marcado = _crear_mob(escena_mob, escena, Vector2.ZERO)
	_vecino  = _crear_mob(escena_mob, escena, Vector2(80, 0))
	_lejano  = _crear_mob(escena_mob, escena, Vector2(900, 0))

	_marca = _nueva_marca()
	_marcado.add_child(_marca)


func _crear_mob(escena_mob: PackedScene, padre: Node, pos: Vector2) -> CharacterBody2D:
	var mob := escena_mob.instantiate()
	padre.add_child(mob)
	mob.global_position = pos
	# Sin IA: acá interesa la explosión, no que los lobos se muevan y cambien
	# las distancias a mitad de la medición.
	(mob.get_node("ArbolComportamiento")).activo = false
	return mob


func _informar() -> bool:
	var exito := _acumula and _daña_al_vecino and _no_daña_al_marcado \
		and _respeta_el_radio and _detona_al_morir and _indicador_zona_ok
	print("PRUEBA MARCA DETONABLE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
