class_name HabilidadArañazo
extends HabilidadGolpeBasico
## Arañazo instancia Arañazo.tscn (efímero) en lugar de GolpeBasico.tscn.
## radio_golpe se puede configurar desde un DatosHabilidad.tres via aplicar_datos().

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Arañazo"
	tipo_habilidad   = "arañazo"


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	# Reutiliza un arañazo ya creado en vez de instanciar uno nuevo cada vez
	# (object pooling: ver GestorPiscinas).
	var golpe := GestorPiscinas.obtener(escena_golpe) as Arañazo
	if not golpe:
		push_error("HabilidadArañazo: escena_golpe debe ser de tipo Arañazo")
		return
	var frente := direccion if direccion.length() > 0.1 else Vector2.RIGHT
	golpe.global_position = entidad_dueña.global_position + frente * alcance_golpe
	golpe.configurar(_calcular_dano(int(daño)), radio_golpe, entidad_dueña, duracion_golpe, tipo_dano)


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.radio_golpe > 0.0:
		radio_golpe = d.radio_golpe
