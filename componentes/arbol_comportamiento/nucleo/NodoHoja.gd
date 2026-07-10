# =============================================================================
# NodoHoja.gd
# Clase BASE ABSTRACTA para nodos hoja (Accion, Condicion).
# Los nodos hoja NO tienen hijos — son los comportamientos concretos del árbol.
# NO usar directamente — extender Accion o Condicion para implementar lógica.
# =============================================================================
class_name NodoHoja
extends NodoBT

# Los nodos hoja no gestionan hijos.
# _on_ejecutar() DEBE ser sobreescrito obligatoriamente en la subclase concreta.
#
# Ejemplo de uso:
#   extends Accion          # o extends Condicion
#
#   func _on_ejecutar() -> Estado:
#       if agente.esta_cerca_del_objetivo():
#           return Estado.EXITOSO
#       return Estado.FALLIDO
