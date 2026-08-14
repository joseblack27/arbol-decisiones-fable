extends FuenteObjetos
class_name FuenteCofre
## Delega en CofresComponente — UNA sola instancia compartida por toda la
## grilla del cofre (no una por casilla: sin posiciones fijas, ver
## CofresComponente, no hace falta más que id_cofre).

var cofres: CofresComponente
var id_cofre: String = ""


func agregar(item: DatosItem) -> bool:
	return cofres.agregar(id_cofre, item) if cofres else false


func quitar(item: DatosItem) -> void:
	if cofres:
		cofres.quitar(id_cofre, item)
