extends VScrollBar

@export var scroll_container: ScrollContainer

func _ready():
	# 1. Obtenemos la barra original (interna) del contenedor
	var internal_v_bar = scroll_container.get_v_scroll_bar()
	
	# 2. Sincronizamos el tamaño y rango inicialmente
	_sync_scrollbar_properties()
	
	# 3. Conectamos señales en ambas direcciones:
	
	# Si mueves la barra personalizada -> el contenedor se mueve
	value_changed.connect(func(val): 
		scroll_container.scroll_vertical = val 
	)
	
	# Si usas la rueda del ratón en el contenedor -> la barra personalizada se mueve
	internal_v_bar.value_changed.connect(func(val): 
		value = val 
	)

	# 4. Importante: Si el contenido cambia de tamaño, hay que actualizar los límites
	internal_v_bar.changed.connect(_sync_scrollbar_properties)

func _sync_scrollbar_properties():
	var internal_v_bar = scroll_container.get_v_scroll_bar()
	
	# Copiamos los valores esenciales
	max_value = internal_v_bar.max_value
	step = internal_v_bar.step
	page = internal_v_bar.page # Esto define el tamaño del "grabber"
	
	visible = internal_v_bar.max_value > internal_v_bar.page
