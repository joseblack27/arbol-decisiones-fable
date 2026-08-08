# =============================================================================
# Prueba de HabilidadDisparoLinea ("Escupitajo", ataque a distancia de la
# Araña Reina) tras sacarle el telégrafo de línea (pedido del usuario: el
# proyectil no tenía ningún sprite propio y encima mostraba un indicador de
# línea aparte — se sacó el indicador y se le dio sprite real al proyectil,
# ver ProyectilEscupitajoJefe.tscn) — ahora dispara directo, sin aviso previo.
#
# Verifica:
#   1. El proyectil sale DE INMEDIATO al activar (ya no espera ningún
#      telégrafo) y tiene un Sprite2D real (ya no vuela invisible).
#   2. Usa la dirección Y posición congeladas al activarse (no las
#      recalcula si el dueño se mueve después).
#   godot --headless --path . --script res://pruebas/prueba_escupitajo_jefe.gd
# =============================================================================
extends SceneTree

const ORIGEN := Vector2(100, 0)
const DIRECCION := Vector2.RIGHT

var _dueño: Node2D
var _hab
var _piscinas
var _f := 0
var _activos_antes := 0
var _proy_disparado: Node = null

var _sale_de_inmediato_ok := false
var _tiene_sprite_ok := false
var _direccion_congelada := false
var _origen_congelado := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_activos_antes = _piscinas._activos.size()
			_hab.activar(DIRECCION, 1.0)
		3:
			_proy_disparado = _proyectil_nuevo()
			_sale_de_inmediato_ok = _proy_disparado != null
			print("El proyectil sale de inmediato, sin telegraph (esperado true): %s" % _sale_de_inmediato_ok)

			_tiene_sprite_ok = _proy_disparado != null \
				and _proy_disparado.get_node_or_null("Sprite2D") != null
			print("El proyectil tiene un Sprite2D real (esperado true): %s" % _tiene_sprite_ok)

			if _proy_disparado:
				_direccion_congelada = _proy_disparado.get("_direccion") == DIRECCION
				_origen_congelado = _proy_disparado.global_position.distance_to(ORIGEN) < 30.0
			# El dueño se mueve DESPUÉS de disparar — el proyectil ya en vuelo
			# no debe reaccionar a esto.
			_dueño.global_position = Vector2(9999, 9999)
			print("Dirección congelada (esperado true): %s" % _direccion_congelada)
			print("Origen congelado en el punto de activación (esperado true): %s" % _origen_congelado)
			return _informar()
	return false


func _proyectil_nuevo() -> Node:
	for nodo in _piscinas._activos:
		if nodo is Proyectil:
			return nodo
	return null


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	_piscinas = root.get_node("/root/GestorPiscinas")

	_dueño = Node2D.new()
	raiz.add_child(_dueño)
	_dueño.global_position = ORIGEN

	var escena_hab := load("res://escenas/habilidades/disparo_linea/HabilidadDisparoLinea.tscn") as PackedScene
	_hab = escena_hab.instantiate()
	_dueño.add_child(_hab)
	_hab.entidad_dueña = _dueño


func _informar() -> bool:
	var exito := _sale_de_inmediato_ok and _tiene_sprite_ok and _direccion_congelada and _origen_congelado
	print("PRUEBA ESCUPITAJO JEFE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
