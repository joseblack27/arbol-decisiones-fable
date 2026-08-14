extends RefCounted
class_name FuenteObjetos
## Adaptador entre una GrillaObjetos y la colección real que representa —
## quien recibe un drop (ver ScrollContainerObjetos._drop_data) llama
## agregar()/quitar() sobre la fuente de CADA lado nada más; ninguna
## colección conoce ni le importa cómo persiste la otra. Una única
## instancia compartida por TODA la grilla (sin estado por casilla — acá
## no hay posiciones fijas, ver FuenteInventario/FuenteCofre).

## false si no hay lugar (ej. cofre lleno, ver FuenteCofre) — el llamador
## NO debe quitar el ítem de su origen si esto devuelve false, o se
## perdería sin entrar a ningún lado.
func agregar(_item: DatosItem) -> bool:
	return true


func quitar(_item: DatosItem) -> void:
	pass
