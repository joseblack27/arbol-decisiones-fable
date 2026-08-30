class_name HabilidadEscudoReflectanteGuardian
extends HabilidadEscudo
## Igual que HabilidadEscudo (activa un EscudoComponente temporal), pero
## instancia EscudoReflectanteComponente en vez del componente base — la
## porción de daño bloqueada vuelve contra quien atacó (ver ese archivo).
## Sigue creando el nodo con el nombre "EscudoComponente" (mismo criterio
## que la base): VidaComponente.quitar_vida() lo busca por NOMBRE, no por
## tipo, y como EscudoReflectanteComponente extends EscudoComponente, el
## cast "as EscudoComponente" de ahí sigue funcionando sin tocar nada.
##
## Sin .tscn propio — habilidad de MOB, se agrega como script node directo
## dentro de EnemigoGuardianQuebrado.tscn.


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Escudo Reflectante"
	tipo_habilidad   = "escudo_reflectante_guardian"


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	if _componente_escudo == null:
		_componente_escudo = entidad_dueña.get_node_or_null("EscudoComponente") as EscudoComponente
		if _componente_escudo == null:
			_componente_escudo = EscudoReflectanteComponente.new()
			_componente_escudo.name = "EscudoComponente"
			entidad_dueña.add_child(_componente_escudo)
	_componente_escudo.activar(duracion_escudo, reduccion)

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		buffs.agregar("escudo_reflectante", icono_buff, duracion_escudo, false,
			nombre_habilidad, "Refleja el daño bloqueado contra quien ataca")
