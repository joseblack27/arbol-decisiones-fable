class_name HabilidadFlechaArquero
extends HabilidadProyectil
## Variante de HabilidadFlecha exclusiva del Esqueleto Arquero: en vez de
## disparar instantáneo, primero entra al estado ATACAR del AnimationTree
## (condiciones "debeAtacar"/"debeIdle", ver EnemigoEsqueletoArquero.tscn) y
## se queda QUIETO duracion_pose_ataque segundos — recién cuando termina esa
## pose sale la flecha de verdad (spawneada por HabilidadProyectil._ejecutar,
## vía super()) y arranca la recuperación normal. Pedido explícito del
## usuario: "que se quede quieto hasta que termine la animación, y después
## de terminar es cuando sale la flecha, entra en el cooldown y pasa al
## siguiente estado".
##
## El congelamiento de movimiento reusa memoria["ataque_en_curso"] — el
## mismo mecanismo que ya usa HabilidadCarga para la preparación de la
## mordida del Lobo (ver AccionAtacar._on_ejecutar: mientras esté en true,
## corta ANTES de reposicionarse/reapuntar) y que EnemigoEsqueletoArquero ya
## usa para su propia retirada. Con esto congelado, el "cooldown" real
## (AccionAtacar.duracion_recuperacion, cuyo timestamp arranca desde
## activar()) queda invisible durante la pose y solo se nota recién cuando
## se libera el movimiento al terminar — el efecto observable es "primero
## la pose, después sale la flecha, después la recuperación", tal como se
## pidió.
##
## Subclase propia (no directo en HabilidadProyectil, compartida por
## Gancho/Rebote/Bola de Fuego/etc.) para no acoplar ese script genérico a
## un componente_animacion/memoria que la mayoría de sus usos ni tiene.
##
## _ejecutar() sigue siendo el hook correcto (no habilidad_activada/
## activar()): corre en TODOS los peers relevantes — quien dispara Y cada
## espectador, vía HabilidadBase._reproducir_visual_red — así se ve la
## misma pausa y el mismo disparo en todos lados, no solo del lado de quien
## decide el disparo. El blend direccional de ATACAR no hace falta tocarlo
## acá: ya está en params_blend_adicionales del AnimacionComponente del
## arquero, así que lo orienta solo el mismo actualizar_blend() que ya
## corre cada fotograma para CAMINAR/IDLE.
##
## Sigue apuntando al objetivo MIENTRAS dura la pose (_process() de acá
## abajo actualiza direccion_mirada cada fotograma) — pedido explícito del
## usuario: "quiero que el arquero apunte hasta la última posición donde
## estuvo el jugador hasta que salga la flecha, porque si no es muy fácil
## esquivarlo". AccionAtacar normalmente hace este reapuntado, pero lo
## corta mientras ataque_en_curso esté activo (ver Enemigo._aplicar_
## presentacion) — acá se retoma esa misma responsabilidad, SOLO durante
## la pose propia. La flecha usa la ÚLTIMA dirección apuntada de verdad
## (leída de entidad_dueña.direccion_mirada al terminar la pose), no la que
## tenía el jugador cuando arrancó — "direccion" (el parámetro original)
## queda solo de respaldo si direccion_mirada no fuera utilizable.

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
		# No alcanza con la condición sola: el grafo solo tiene la arista
		# IDLE->ATACAR. Si el arquero todavía está en CAMINAR (recién
		# saliendo de reposicionarse, el caso más común) esa condición no
		# tiene ninguna arista de salida que la escuche desde ahí y se
		# queda pegado mostrando caminar — reportado por el usuario:
		# "la mayoría de las veces hace la de caminata". viajar_a_estado()
		# fuerza el viaje pase lo que pase (ver AnimacionComponente).
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
