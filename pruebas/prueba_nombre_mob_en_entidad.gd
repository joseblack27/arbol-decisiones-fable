# =============================================================================
# Prueba: el nombre del mob ("Nv.X Nombre") vive en Enemigo.gd (la entidad),
# no en BarraVidaEnergiaComponente — se movió porque el nombre es una
# propiedad del mob, no de sus barras de vida/energía (pedido del usuario al
# ver que ambos vivían mezclados en el mismo componente).
#
# Verifica:
#   1. Enemigo._crear_nombre_mob() arma "Nv.X Nombre" desde EnemigoDatos.
#   2. El nodo de dibujo (_nodo_nombre) queda DESPUÉS del Sprite2D entre los
#      hijos — necesario para pintarse encima (Godot pinta hermanos en orden
#      de árbol); si quedara antes, un sprite grande como el del Jefe
#      Esqueleto lo taparía.
#   3. BarraVidaEnergiaComponente ya NO expone nada de nombre (ni
#      _texto_nombre ni tamano_fuente): quedó solo con las barras.
#   4. Un mob SIN EnemigoDatos asignado (como AliadoInvocado) no crea el nodo
#      de nombre — mismo criterio que tenía antes el componente.
#   godot --headless --path . --script res://pruebas/prueba_nombre_mob_en_entidad.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lobo: Node
var _aliado: Node

var _texto_ok := false
var _orden_ok := false
var _barra_sin_nombre_ok := false
var _sin_datos_no_dibuja_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_verificar()
			return _informar()
	return false


func _montar() -> void:
	_lobo = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	root.add_child(_lobo)
	_aliado = (load("res://escenas/enemigos/AliadoInvocado.tscn") as PackedScene).instantiate()
	root.add_child(_aliado)


func _verificar() -> void:
	var texto: String = _lobo.get("_texto_nombre")
	print("Texto del nombre del Lobo (esperado 'Nv.X Lobo'): '%s'" % texto)
	_texto_ok = texto.begins_with("Nv.") and texto.ends_with("Lobo")

	var indice_sprite := _lobo.get_node("Sprite2D").get_index()
	var nodo_nombre = _lobo.get_node_or_null("NombreMob")
	var indice_nombre := nodo_nombre.get_index() if nodo_nombre else -1
	print("Índice del Sprite2D: %d — índice de NombreMob: %d (debe ser mayor)" % [
		indice_sprite, indice_nombre])
	_orden_ok = nodo_nombre != null and indice_nombre > indice_sprite

	var barra := _lobo.get_node("BarraVidaEnergia")
	var le_queda_nombre := "tamano_fuente" in barra or "_texto_nombre" in barra \
		or "mostrar_nombre" in barra
	print("BarraVidaEnergia ya no sabe nada de nombre (esperado true): %s" % (not le_queda_nombre))
	_barra_sin_nombre_ok = not le_queda_nombre

	var nodo_nombre_aliado = _aliado.get_node_or_null("NombreMob")
	print("Aliado invocado (sin EnemigoDatos) no crea NombreMob (esperado true): %s" % (
		nodo_nombre_aliado == null))
	_sin_datos_no_dibuja_ok = nodo_nombre_aliado == null


func _informar() -> bool:
	var exito := _texto_ok and _orden_ok and _barra_sin_nombre_ok and _sin_datos_no_dibuja_ok
	print("  texto del nombre: %s" % _texto_ok)
	print("  orden de dibujo (encima del sprite): %s" % _orden_ok)
	print("  barra de vida/energía sin lógica de nombre: %s" % _barra_sin_nombre_ok)
	print("  sin datos no dibuja nombre: %s" % _sin_datos_no_dibuja_ok)
	print("PRUEBA NOMBRE MOB EN ENTIDAD %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
