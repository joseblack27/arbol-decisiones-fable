class_name HabilidadFlechaArquero
extends HabilidadProyectil
## Variante de HabilidadFlecha exclusiva del Esqueleto Arquero: en vez de
## disparar al instante, entra al estado ATACAR del AnimationTree (condiciones
## "debeAtacar"/"debeIdle", ver EnemigoEsqueletoArquero.tscn) y se queda
## QUIETO duracion_pose_ataque segundos; recién al terminar la pose sale la
## flecha (HabilidadProyectil._ejecutar, vía super()) y arranca la
## recuperación normal.
##
## El congelamiento reusa memoria["ataque_en_curso"], como HabilidadCarga con
## la preparación de la mordida del Lobo (AccionAtacar corta mientras esté en
## true, antes de reposicionarse o reapuntar). El cooldown real
## (AccionAtacar.duracion_recuperacion, contado desde activar()) queda oculto
## durante la pose: primero la pose, después la flecha, después la
## recuperación.
##
## Subclase propia y no dentro de HabilidadProyectil (compartida por Gancho,
## Rebote, Bola de Fuego...) para no acoplar ese script genérico a
## componente_animacion y memoria, que la mayoría de sus usos no tiene.
##
## _ejecutar() es el hook correcto (no habilidad_activada/activar()): corre en
## TODOS los peers relevantes, quien dispara y cada espectador vía
## HabilidadBase._reproducir_visual_red, así todos ven la misma pausa. El
## blend direccional de ATACAR ya está en params_blend_adicionales del
## AnimacionComponente del arquero, así que lo orienta el mismo
## actualizar_blend() de CAMINAR/IDLE.
##
## Sigue apuntando al objetivo MIENTRAS dura la pose (_process() actualiza
## direccion_mirada cada fotograma); si no, sería muy fácil esquivarlo.
## AccionAtacar normalmente reapunta, pero no mientras ataque_en_curso esté
## activo; acá se retoma solo durante la pose. La flecha sale con la ÚLTIMA
## dirección apuntada (entidad_dueña.direccion_mirada al terminar la pose);
## "direccion" queda de respaldo.

## Cuánto dura la pose antes de que salga la flecha — por defecto, la
## duración real de los clips ataque_* (1.2s, ver EnemigoEsqueletoArquero.
## tscn). Ajustable desde el Inspector.
@export var duracion_pose_ataque: float = 1.2

## Identifica la preparación más reciente — si por lo que sea arrancara una
## segunda antes de que la primera dispare (no debería pasar en juego
## normal: AccionAtacar no vuelve a intentar hasta pasar duracion_
## recuperacion), el temporizador viejo no debe disparar la flecha vieja ni
## pisar el estado que dejó la nueva.
var _id_disparo := 0
## true mientras dura la pose — gatilla el reapuntado continuo en _process().
var _en_pose := false

func _ejecutar(direccion: Vector2, poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	_id_disparo += 1
	var id_esta_preparacion := _id_disparo
	_en_pose = true

	if "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", true)

	var animacion: AnimacionComponente = null
	if "componente_animacion" in entidad_dueña:
		animacion = entidad_dueña.componente_animacion
	if animacion:
		animacion.establecer_condicion("parameters/conditions/debeAtacar", true)
		animacion.establecer_condicion("parameters/conditions/debeIdle", false)
		# No alcanza con la condición: el grafo solo tiene la arista
		# IDLE->ATACAR, y si el arquero todavía está en CAMINAR (recién
		# reposicionado, lo más común) nada la escucha y sigue mostrando
		# caminar. viajar_a_estado() fuerza el viaje (ver AnimacionComponente).
		animacion.viajar_a_estado("ATACAR")

	get_tree().create_timer(duracion_pose_ataque).timeout.connect(
		_al_terminar_pose.bind(id_esta_preparacion, direccion, poder, animacion)
	)


## Reapuntado continuo mientras dura la pose — ver comentario de clase.
## super._process() primero: sigue siendo necesario para que la recarga
## propia de la habilidad (HabilidadBase) siga corriendo como siempre.
func _process(delta: float) -> void:
	super._process(delta)
	if not _en_pose or not is_instance_valid(entidad_dueña) or not ("memoria" in entidad_dueña):
		return
	var objetivo_raw = entidad_dueña.get("memoria").obtener("objetivo")
	if not is_instance_valid(objetivo_raw) or not (objetivo_raw is Node2D):
		return
	var hacia_objetivo: Vector2 = (objetivo_raw as Node2D).global_position - entidad_dueña.global_position
	if hacia_objetivo.length() > 0.1 and "direccion_mirada" in entidad_dueña:
		entidad_dueña.direccion_mirada = hacia_objetivo.normalized()


func _al_terminar_pose(id_esta_preparacion: int, direccion: Vector2, poder: float, animacion: AnimacionComponente) -> void:
	if id_esta_preparacion != _id_disparo or not is_instance_valid(entidad_dueña):
		return
	_en_pose = false
	if "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", false)
	if animacion and is_instance_valid(animacion):
		animacion.establecer_condicion("parameters/conditions/debeAtacar", false)
		animacion.establecer_condicion("parameters/conditions/debeIdle", true)
	var direccion_final := direccion
	if "direccion_mirada" in entidad_dueña:
		var mirada: Vector2 = entidad_dueña.direccion_mirada
		if mirada != Vector2.ZERO:
			direccion_final = mirada
	super._ejecutar(direccion_final, poder)
