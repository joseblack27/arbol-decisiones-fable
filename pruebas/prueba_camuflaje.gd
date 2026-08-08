# =============================================================================
# Prueba del CAMUFLAJE (ver CamuflajeComponente / HabilidadCamuflaje).
#
# Es la única herramienta del juego para SALIR de una pelea: Parpadeo te mueve
# pero los mobs te siguen, y Escudo aguanta el golpe sin resolver la situación.
# Pensada para sobrevivir jugando solo, que es la prioridad del juego.
#
# Verifica:
#   1. Un mob que te tenía FICHADO te SUELTA al ocultarte — no alcanza con que
#      no puedan detectarte de nuevo: el que ya te vio tiene que perderte.
#   2. Estando oculto no te vuelven a tomar como objetivo.
#   3. Al vencer el camuflaje te vuelven a ver.
#   4. Atacar lo corta al instante (si no, sería una invulnerabilidad con
#      golpes gratis).
#   godot --headless --path . --script res://pruebas/prueba_camuflaje.gd
# =============================================================================
extends SceneTree

var _f := 0
var _mob
var _jugador: CharacterBody2D
## Sin anotar el tipo: anotar "CamuflajeComponente" obliga a compilar esa
## clase mientras se parsea esta prueba, antes de que existan los autoloads
## que usa, y se lleva puesta la cadena de dependencias (los mobs quedaban
## ciegos). Mismo criterio que prueba_marca_detonable.
var _camuflaje

var _lo_veia_antes := false
var _lo_suelta_al_ocultarse := false
var _no_lo_vuelve_a_ver := false
var _lo_ve_al_terminar := false
var _atacar_lo_corta := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		# Margen para que el cono de visión lo fiche y el árbol lo anote.
		30:
			_lo_veia_antes = _lo_tiene_fichado()
			print("El mob lo tenía fichado antes de ocultarse (esperado true): %s" % _lo_veia_antes)
			_camuflaje.activar(1.0)
		# _INTERVALO_PODA de VisionComponente es 0.5s: con 45 fotogramas
		# (0.75s) ya tuvo que soltarlo.
		75:
			_lo_suelta_al_ocultarse = not _lo_tiene_fichado()
			print("Al ocultarse el mob lo suelta (esperado true): %s" % _lo_suelta_al_ocultarse)
			_no_lo_vuelve_a_ver = not _lo_tiene_fichado()
		# El camuflaje de 1s ya venció; se le da margen a la redetección.
		140:
			_lo_ve_al_terminar = _lo_tiene_fichado()
			print("Al vencer el camuflaje lo vuelve a ver (esperado true): %s" % _lo_ve_al_terminar)
			# Ahora se prueba el corte por ataque.
			_camuflaje.activar(5.0)
		145:
			var oculto_antes: bool = _camuflaje.esta_activo()
			# Cualquier daño cuya FUENTE sea el jugador lo delata, venga de la
			# habilidad que venga (por eso se escucha el bus y no cada una).
			# En un guion pasado por --script los autoloads no resuelven como
			# identificador suelto: hay que pedirlos por ruta.
			var bus = root.get_node("/root/BusEventos")
			bus.daño_aplicado.emit(_mob, 10.0, _jugador, 2, false)
			_atacar_lo_corta = oculto_antes and not _camuflaje.esta_activo()
			print("Atacar corta el camuflaje al instante (esperado true, estaba oculto=%s): %s" % [
				oculto_antes, _atacar_lo_corta])
			return _informar()
	return false


## "Fichado" = el mob lo tiene como objetivo real de su IA.
func _lo_tiene_fichado() -> bool:
	var vision := _mob.get_node("VisionComponente") as VisionComponente
	return vision.areas_detectadas.size() > 0


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(_jugador)
	_jugador.global_position = Vector2(60, 0)
	# La protección de aparición ya excluye al jugador de la visión de los
	# mobs: se la saca para que lo que se mida acá sea SOLO el camuflaje.
	_jugador.get_node("VidaComponente").cancelar_invulnerabilidad()

	_camuflaje = Node.new()
	_camuflaje.name = "CamuflajeComponente"
	_camuflaje.set_script(load("res://componentes/CamuflajeComponente.gd"))
	_jugador.add_child(_camuflaje)

	_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	escena.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	# Sin IA: acá interesa la DETECCIÓN, no que el lobo se mueva y cambie las
	# distancias a mitad de la medición.
	(_mob.get_node("ArbolComportamiento")).activo = false


func _informar() -> bool:
	var exito := _lo_veia_antes and _lo_suelta_al_ocultarse and _no_lo_vuelve_a_ver \
		and _lo_ve_al_terminar and _atacar_lo_corta
	print("PRUEBA CAMUFLAJE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
