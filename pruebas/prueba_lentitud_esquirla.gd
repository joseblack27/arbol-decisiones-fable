# =============================================================================
# Prueba del debuff de lentitud de Esquirla helada (EfectoLentitud):
#   1. Un proyectil de esquirla que impacta a un mob le pega el efecto: su
#      MovimientoComponente pasa a multiplicador 0.5.
#   2. El debuff queda anotado en BuffsComponente (ícono para la UI), creado
#      al vuelo en el mob.
#   3. Un segundo impacto RENUEVA la duración, no apila (multiplicador sigue
#      en 0.5, nunca 0.25).
#   4. Pasada la duración (3s), la lentitud se limpia sola (multiplicador
#      vuelve a 1.0) y el buff desaparece de BuffsComponente.
#   godot --headless --path . --script res://pruebas/prueba_lentitud_esquirla.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _mob
var _atacante: Node2D
var _mitad_ok := false
var _icono_ok := false
var _sin_apilar_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_disparar()
		15:
			var mov = _mob.get_node("MovimientoComponente")
			_mitad_ok = is_equal_approx(mov._multiplicador_lentitud(), 0.5)
			var buffs = _mob.get_node_or_null("BuffsComponente")
			_icono_ok = buffs != null and buffs.esta_activo("lentitud_esquirla")
			print("Multiplicador tras impacto (esperado 0.5): %.2f" % mov._multiplicador_lentitud())
			print("Debuff anotado en BuffsComponente (esperado true): %s" % _icono_ok)
			_disparar()
		30:
			var mov = _mob.get_node("MovimientoComponente")
			_sin_apilar_ok = is_equal_approx(mov._multiplicador_lentitud(), 0.5)
			print("Segundo impacto renueva sin apilar (esperado 0.5): %.2f" % mov._multiplicador_lentitud())
		# duracion=3s ≈ 180 fotogramas después del segundo impacto (frame 15).
		230:
			var mov = _mob.get_node("MovimientoComponente")
			var buffs = _mob.get_node_or_null("BuffsComponente")
			var limpio_ok: bool = is_equal_approx(mov._multiplicador_lentitud(), 1.0)
			var buff_fuera_ok: bool = buffs == null or not buffs.esta_activo("lentitud_esquirla")
			print("Multiplicador tras expirar (esperado 1.0): %.2f" % mov._multiplicador_lentitud())
			print("Buff fuera de BuffsComponente tras expirar (esperado true): %s" % buff_fuera_ok)
			var exito := _mitad_ok and _icono_ok and _sin_apilar_ok and limpio_ok and buff_fuera_ok
			print("PRUEBA LENTITUD ESQUIRLA %s" % ("OK" if exito else "FALLIDA"))
			quit(0 if exito else 1)
			return true
	return false


func _montar() -> void:
	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	root.add_child(_atacante)
	current_scene = _atacante
	_atacante.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2(60, 0)


func _disparar() -> void:
	var proy = (load("res://escenas/habilidades/esquirla/ProyectilEsquirla.tscn") as PackedScene).instantiate()
	root.add_child(proy)
	proy.global_position = Vector2.ZERO
	proy.alcance_base = 400.0
	proy.configurar(Vector2.RIGHT, 1.0, 10, _atacante, Enums.Habilidad.TipoDano.AGUA)
