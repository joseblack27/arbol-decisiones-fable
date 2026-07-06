# =============================================================================
# MonitorVariable.gd  (Resource)
# Define una variable monitoreada: vincula una propiedad de un nodo
# de la escena con un nombre de variable dentro de la MemoriaBT.
#
# USO: Crear desde el Inspector de MemoriaBT en el array "monitores_exportados".
# =============================================================================
class_name MonitorVariable
extends Resource

## Nombre con el que se guardará el valor en la MemoriaBT.
@export var nombre_variable: String = ""
## Ruta al nodo cuya propiedad se va a monitorizar.
@export var ruta_nodo: NodePath
## Nombre exacto de la propiedad del nodo a leer (ej: "health", "velocity").
@export var propiedad: String = ""
