# =============================================================================
# Prueba: al llegar la vida de un enemigo a 0, el nodo REALMENTE desaparece
# (antes se congelaba pero se quedaba en la escena para siempre).
#   godot --headless --path . --script res://pruebas/prueba_muerte_mobs.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _raton: Node
var _id_instancia: int
var _barra: CanvasItem
var _barra_oculta_al_instante := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		10:
			# Matar de un golpe.
			var vida := _raton.get_node("VidaComponente")
			vida.quitar_vida(9999.0)
		11:
			# La barra de vida debe ocultarse en el mismo fotograma de la
			# muerte, antes de que avance la animación/desvanecido.
			_barra_oculta_al_instante = not _barra.visible
			print("Barra oculta al instante tras morir: %s" % _barra_oculta_al_instante)
		40:
			if is_instance_valid(_raton):
				print("DEPURACION t=40 modulate.a=%.2f collision_layer=%d" % [
					_raton.modulate.a, _raton.collision_layer,
				])
			else:
				print("DEPURACION t=40 ya no es válido")
		# El desvanecido ahora tiene dos etapas (a negro + fundido, 0.8s en
		# total); se comprueba con margen amplio.
		250:
			return _informar()
	return false


func _montar() -> void:
	var escena := (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(escena)
	_raton = escena
	_id_instancia = _raton.get_instance_id()
	_barra = _raton.get_node("BarraVidaEnergia") as CanvasItem


func _informar() -> bool:
	var sigue_vivo := is_instance_valid(_raton)
	print("¿El ratón sigue existiendo tras morir? (esperado false): %s" % sigue_vivo)
	var exito := not sigue_vivo and _barra_oculta_al_instante
	print("PRUEBA MUERTE MOBS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
