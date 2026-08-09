extends Resource
class_name OpcionDialogo
## Una opción elegible dentro de una LineaDialogo (ver DatosDialogo).

@export var texto: String = ""
## Índice (dentro de DatosDialogo.lineas) al que salta esta opción. -1 = cierra el diálogo.
@export var siguiente_linea: int = -1
@export var accion: Enums.Dialogo.Accion = Enums.Dialogo.Accion.NINGUNA
## Solo se usa cuando accion es ACEPTAR_MISION o ENTREGAR_MISION — cuál de
## las misiones que ofrece el NPC (Npc.misiones_ofrecidas) aplica esta
## opción puntual. Sin esto, un NPC con más de una misión ofrecida sería
## ambiguo (¿cuál acepta el botón "Sí"?).
@export var mision_objetivo: DatosMision = null

## Filtro de visibilidad — PanelDialogo la oculta si no se cumple (ver
## Enums.Dialogo.CondicionMision). SIEMPRE (default) = nunca se filtra,
## no hace falta llenar mision_condicion. Independiente de mision_
## objetivo/accion de arriba: una opción puede depender del estado de una
## misión sin ser ella misma la que la acepta/entrega (p. ej. "tengo una
## misión para vos", que solo NAVEGA a otra línea, debería dejar de
## ofrecerse una vez que esa misión ya se aceptó).
@export var condicion: Enums.Dialogo.CondicionMision = Enums.Dialogo.CondicionMision.SIEMPRE
@export var mision_condicion: DatosMision = null

## Puramente visual (ver Enums.Dialogo.CategoriaOpcion) — NINGUNA (default)
## no dibuja ícono, para no romper opciones ya existentes. Independiente de
## condicion/accion: es el autor del diálogo quien elige qué ícono mostrar,
## no algo derivado automáticamente (ej. "Ahora no" tiene accion=NINGUNA
## igual que una opción de lore, pero no queremos el mismo ícono en ambas).
@export var categoria: Enums.Dialogo.CategoriaOpcion = Enums.Dialogo.CategoriaOpcion.NINGUNA
