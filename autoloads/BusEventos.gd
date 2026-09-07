extends Node
## BusEventos.gd — Hub central de señales para comunicación entre sistemas.
## Todos los sistemas del juego se comunican aquí para mantenerse desacoplados.
## Uso: BusEventos.nombre_señal.emit(argumentos)
##
## CONFIGURACIÓN: Añadir como Autoload en Proyecto > Ajustes del Proyecto > Autoloads
## Nombre del autoload: BusEventos
## Ruta: res://autoloads/BusEventos.gd

# ── JUGADOR ──────────────────────────────────────────────────────────────────
## Emitida cuando la vida del jugador cambia (vida_actual, vida_maxima).
signal salud_jugador_cambiada(vida_actual: float, vida_maxima: float)
## Emitida cuando el jugador LOCAL muere (nunca por la muerte de un jugador
## replicado ajeno — ver Jugador._morir, gateado a _es_dueño_local()).
## "tiempo_reaparicion" es Jugador.TIEMPO_REAPARICION, para que quien
## escuche (PanelGameOver) arme la cuenta regresiva sin acoplarse a esa
## constante directo.
signal jugador_murio(tiempo_reaparicion: float)
## Emitida cuando el jugador LOCAL reaparece en una posición (mismo gateo
## que jugador_murio — ver Jugador._revivir).
signal jugador_reaparecio(posicion: Vector2)

# ── COMBATE ──────────────────────────────────────────────────────────────────
## Emitida cuando una entidad aplica daño a otra (objetivo, cantidad, fuente,
## tipo). "tipo" es el elemento del golpe (Enums.Habilidad.TipoDano, viaja
## como int) — lo usa GestorNumerosDano para pintar el número flotante del
## color del elemento y marcar los golpes a una debilidad elemental.
signal daño_aplicado(objetivo: Node, cantidad: float, fuente: Node, tipo: int, critico: bool)
## Solo en clientes puros: daño real replicado desde el servidor, con el
## nombre del atacante YA resuelto como texto — incluso si el nodo atacante
## no existe en este peer (mob invisible: se deriva de la ruta que mandó el
## servidor y se marca "[invisible]"). El log de Actividad Reciente usa esta
## señal en red; daño_aplicado sigue siendo la señal general (números de
## daño, etc.), pero su "fuente: Node" es null cuando el nodo no está acá.
signal daño_replicado(objetivo: Node, cantidad: float, nombre_fuente: String)
## Emitida cuando una entidad recibe daño (objetivo, cantidad).
signal daño_recibido(objetivo: Node, cantidad: float)
## Emitida cuando una entidad se cura de verdad (objetivo, cantidad real
## aplicada, ya recortada al máximo). VidaComponente.agregar_vida() (y su
## réplica de red, _recibir_vida_red) es el único punto por el que pasa TODA
## curación (HoT de Curación, ítems, robo de vida de Golpe Vampírico,
## regeneración pasiva, full-heal al reaparecer/subir de nivel) — emitirla
## ahí cubre todos los casos sin tocar cada llamador. Ver
## GestorNumerosCuracion (pinta el "+N" verde flotante).
signal curacion_aplicada(objetivo: Node, cantidad: float)
## Emitida cuando cualquier entidad muere.
signal entidad_murio(entidad: Node)

# ── HABILIDADES ──────────────────────────────────────────────────────────────
## Emitida cuando una entidad usa una habilidad (entidad, tipo_habilidad).
signal habilidad_usada(entidad: Node, tipo_habilidad: String)
## Emitida cuando una habilidad impacta a un objetivo (tipo_habilidad, objetivo).
signal habilidad_impacto(tipo_habilidad: String, objetivo: Node)
## Emitida cuando una habilidad entra en recarga (entidad, slot_index, duracion).
## slot_index = -1 para habilidades que no están en un slot (enemigos, etc.).
signal recarga_iniciada(entidad: Node, slot_index: int, duracion: float)
## Emitida cuando la recarga de una habilidad termina (entidad, slot_index).
signal recarga_terminada(entidad: Node, slot_index: int)
## Emitida por habilidades de DOS ETAPAS (activar → esperar → detonar, ver
## HabilidadAcumulacion) al entrar o salir de la segunda etapa — el botón
## (ver UIHabilidad._on_fase_cambiada) cambia de color mientras "activa" es
## true, para que se note a simple vista que la habilidad ya no está en su
## primer estado (recién presionada) sino esperando la segunda presión o el
## vencimiento. slot_index = -1 para habilidades sin slot (enemigos, etc.).
signal habilidad_fase_cambiada(entidad: Node, slot_index: int, activa: bool)

# ── ENERGÍA ──────────────────────────────────────────────────────────────────
## Emitida cuando la energía de una entidad cambia (entidad, nueva, maxima).
signal energia_cambiada(entidad: Node, nueva: float, maxima: float)

# ── EQUIPAMIENTO ──────────────────────────────────────────────────────────────
## Emitida cuando una habilidad es equipada en un slot (entidad, slot_index, habilidad).
signal habilidad_equipada(entidad: Node, slot_index: int, habilidad: HabilidadBase)

# ── INVENTARIO ────────────────────────────────────────────────────────────────
## Emitida cuando se añade un ítem al inventario del jugador (ítem, cantidad
## añadida en esa operación — puede ser una entrada nueva o una suma a una pila).
signal item_agregado(item: DatosItem, cantidad: int)
## Emitida SIEMPRE que InventarioComponente.items cambia de cualquier forma
## (agregar, quitar, quitar_cantidad) — a diferencia de item_agregado, NO se
## apaga con silencioso=true. Bug real reportado: "cuando paso objetos del
## cofre al inventario... lo que haya hecho no se sincroniza acá [PanelInventario]"
## — FuenteInventario.agregar() siempre llama agregar_item(..., silencioso=true)
## (para no disparar el popup de "obtuviste X" al mover algo que ya era tuyo),
## así que item_agregado nunca llegaba a PanelInventario en ese flujo. Sin
## argumentos a propósito: quien la escucha (PanelInventario.refrescar_diferido)
## reconstruye TODA la grilla desde GestorInventario.items igual, no le importa
## qué cambió puntualmente.
signal inventario_cambiado
## Emitida cuando cambia el equipo puesto (equipar, quitar o reemplazar
## cualquier pieza) — trae la lista completa de ítems equipados en ese momento.
signal equipo_cambiado(equipados: Array[DatosItem])

# ── EXPERIENCIA ───────────────────────────────────────────────────────────────
## Emitida cuando el jugador gana experiencia (cantidad ganada, xp total
## acumulada).
signal xp_agregada(cantidad: int, xp_total: int)
## Emitida cuando el jugador sube de nivel (ver TablaNiveles/
## ExperienciaComponente). Si una ganancia grande de XP cruza varios
## niveles de una vez, se emite una vez por nivel alcanzado.
signal nivel_subido(nivel_nuevo: int)

# ── PASIVAS ───────────────────────────────────────────────────────────────────
## Emitida al desbloquear CUALQUIER pasiva (de estadística por nivel, o de
## gatillo por ítem especial — ver ExperienciaComponente.pasivas_stat y
## PasivasComponente.desbloquear_gatillo) — para la notificación en pantalla
## y la UI de solo lectura del panel de habilidades.
signal pasiva_desbloqueada(entidad: Node, nombre: String, descripcion: String)
## Emitida al gastar un punto de mejora con éxito (ver MejorasComponente),
## sea en una pasiva de estadística o en una habilidad activa — para el
## autoguardado por evento y el refresco de la UI (indicador de puntos).
signal mejora_comprada(entidad: Node, tipo: String, nombre: String)

# ── CRÉDITOS ──────────────────────────────────────────────────────────────────
## Emitida cuando cambian los créditos de una entidad (entidad, nuevo total).
signal creditos_cambiados(entidad: Node, nuevo: int)

# ── MISIONES ──────────────────────────────────────────────────────────────────
## Informativas para UI/autoguardado — NO son la fuente de verdad del
## progreso (eso vive en MisionesComponente.progreso, por jugador). El
## acreditado real de objetivos usa despacho directo, no este bus: BusEventos
## es una única instancia de autoload compartida por TODOS los Jugador.tscn
## que vive el servidor a la vez, así que un listener acá no puede saber a
## CUÁL jugador corresponde un evento (ver Enemigo._notificar_objetivo_matar
## / InventarioComponente.agregar_item para el mecanismo real de crédito).
signal mision_aceptada(jugador: Node, id_mision: String)
signal mision_completada(jugador: Node, id_mision: String)
signal mision_abandonada(jugador: Node, id_mision: String)
signal mision_progreso_actualizado(jugador: Node, id_mision: String, id_objetivo: String, actual: int, requerido: int)

# ── COFRES ────────────────────────────────────────────────────────────────────
## Un cofre del mundo pide abrir su panel (ver Cofre.gd/PanelCofre) — mismo
## patrón que dialogo_solicitado/tienda_solicitada: PanelCofre se
## autosuscribe en vez de que el cofre necesite una referencia directa.
signal cofre_solicitado(id_cofre: String, nombre_cofre: String)

# ── ALMACÉN DEL LEÑADOR ──────────────────────────────────────────────────────
## El almacén compartido del leñador (ver AlmacenLenador.gd/GestorLenador.gd)
## pide abrir su panel — sin id: a diferencia de los cofres (por jugador),
## este es un pozo único para todo el mundo. Lo abre PanelCofre.gd (modo
## almacén, ver ese archivo) — mismo panel de arrastrar-y-soltar que un
## cofre normal, autosuscrito igual que cofre_solicitado.
signal almacen_lenador_solicitado()

## Mismo criterio que almacen_lenador_solicitado, para el almacén compartido
## del minero (ver AlmacenMinero.gd/GestorMinero.gd).
signal almacen_minero_solicitado()

# ── DIÁLOGO ───────────────────────────────────────────────────────────────────
## Un NPC pide abrir el panel de diálogo con estos datos — PanelDialogo se
## autosuscribe a esta señal (mismo patrón que PanelInventario con el resto
## del bus) en vez de que el NPC necesite una referencia directa al panel.
signal dialogo_solicitado(npc: Node, datos: DatosDialogo)

# ── TIENDA ────────────────────────────────────────────────────────────────────
## Emitida por PanelDialogo al ejecutar una opción con action ABRIR_TIENDA
## — PanelTienda se autosuscribe (mismo patrón que dialogo_solicitado).
## nombre_comerciante: Npc.nombre() del NPC que abrió la tienda, para
## titular la columna de mercancía con quién la vende de verdad.
signal tienda_solicitada(datos: DatosTienda, nombre_comerciante: String)

# ── JUEGO ─────────────────────────────────────────────────────────────────────
signal juego_pausado()
signal juego_reanudado()
## Emitida para solicitar un cambio de escena (ruta_escena).
signal cambio_escena_solicitado(ruta_escena: String)
