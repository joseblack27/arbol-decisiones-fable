# =============================================================================
# HabilidadBT.gd  (Resource)
#
# Define los datos de una habilidad para el SelectorHabilidades.
# Se crea como archivo .tres desde el Inspector (clic derecho → New Resource).
# Un mismo .tres puede reutilizarse en múltiples enemigos o árboles.
#
# CÓMO CREAR UNA HABILIDAD:
#   1. En el FileSystem, clic derecho → New Resource → HabilidadBT.
#   2. Guarda como: res://habilidades/ataque_melee.tres
#   3. Configura sus propiedades desde el Inspector.
#   4. Asígnala al array del SelectorHabilidades.
# =============================================================================
class_name HabilidadBT
extends Resource

@export_group("Identificación")
## Nombre único de la habilidad. Se usa como clave interna (no mostrar al jugador).
@export var nombre: String = "Habilidad"

@export_group("Selección — Prioridad")
## A mayor número, más prioridad frente a otras habilidades disponibles.
## Si dos habilidades pasan todas las condiciones, se elige la de mayor prioridad.
@export var prioridad: int = 0

@export_group("Selección — Rango")
## Distancia mínima al objetivo para poder usar esta habilidad (ej: no usar melee a distancia).
@export var rango_minimo: float = 0.0
## Distancia máxima al objetivo. -1 = sin límite de distancia.
@export var rango_maximo: float = -1.0

@export_group("Cooldown")
## Segundos que deben pasar antes de poder volver a usar esta habilidad.
## 0 = sin cooldown.
@export var duracion_cooldown: float = 0.0

@export_group("Movimiento")
## Si es true, EstadoAtacar se acercará al objetivo cuando esta habilidad esté fuera de rango.
## Ponlo en false para ataques reactivos (ej: arañazo de contraataque) donde el enemigo
## no debe acercarse activamente para usarla.
@export var requiere_acercarse: bool = true

@export_group("Ejecución")
## Ruta del nodo de habilidad relativa al agente (ej: "Habilidades/AtaqueArañazo").
## Si está configurada, SelectorHabilidades llama nodo.activar() directamente.
## Alternativa a metodo_en_agente — usar uno u otro, no ambos.
@export var ruta_nodo: NodePath = NodePath()
## Nombre del método a llamar en el agente al ejecutar esta habilidad.
## Solo se usa si ruta_nodo está vacía.
## Ejemplos: "usar_ataque_melee", "lanzar_proyectil", "activar_escudo"
@export var metodo_en_agente: String = ""
