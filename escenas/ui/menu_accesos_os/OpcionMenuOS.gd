class_name OpcionMenuOS
extends Resource
## Una opción de la cuadrícula de accesos rápidos del botón OS (ver
## MenuAccesosOS.gd) — ícono + qué sección de OsPrincipal abre. Agregar una
## opción nueva a futuro es solo crear un .tres con estos campos y sumarlo
## al array MenuAccesosOS.opciones, sin tocar ningún script — mismo
## criterio que HabilidadBT.gd para el árbol de comportamiento.

@export var icono: Texture2D
## Nombre del método público de OsPrincipal que abre esta sección (ver esa
## clase: _on_btn_inventory, _on_btn_mapa, _on_btn_dashboard...) — se llama
## por nombre con .call(), igual que SelectorHabilidades.metodo_en_agente.
@export var metodo_en_os: String = ""
## Texto del tooltip al mantener el dedo/mouse sobre el ícono.
@export var etiqueta: String = ""
