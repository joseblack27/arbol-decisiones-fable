extends Node


class Inventario:
	enum TipoItem {
		NINGUNO,
		TODOS,
		CONSUMIBLE,
		EQUIPABLE,
		RECURSO,
		MISION,
		ARMA
	}

	enum TipoItemEquipable {
		NINGUNO,
		CASCO,
		CUERPO,
		PANTALON,
		BOTAS,
		AMULETO,
		ANILLO,
		CINTURON,
		ARMA,
		ESCUDO
	}

class Habilidad:
	enum TipoDano {
		TIERRA,
		FUEGO,
		FISICO,
		AGUA,
		AIRE
	}

	## Color (nombre CSS o hex) para mostrar el daño de cada elemento en la
	## descripción de una habilidad — ver PanelDetalleHabilidad.gd. Un solo
	## enum de elemento (TipoDano) para gameplay Y color: antes había un
	## ColorDano aparte con el MISMO elemento en un ORDEN distinto (FISICO
	## en la posición 4 acá, 2 en TipoDano) — un enum totalmente redundante,
	# sin usarse en ningún otro lado, que solo invitaba a mezclar los
	## índices de uno con el otro por error.
	const valor_color_dano := {
		TipoDano.TIERRA: "#905010",
		TipoDano.FUEGO: "red",
		TipoDano.AGUA: "#00c4ff",
		TipoDano.AIRE: "#008f39",
		TipoDano.FISICO: "ghostwhite"
	}

class Evento:
	enum Tipo {
		JEFE_MUNDIAL,
		MAZMORRA,
		INVASION,
		CAMBIO_MUNDIAL,
		FACCION
	}

	enum Estado {
		PROXIMO,
		ACTIVO,
		COMPLETADO,
		FALLIDO,
		CANCELADO
	}

class Mision:
	enum Tipo {
		HISTORIA,
		SECUNDARIA,
		EVENTO,
		DIARIA
	}

	enum Estado {
		BLOQUEADA,
		DISPONIBLE,
		EN_PROGRESO,
		COMPLETADA,
		FALLIDA
	}

	func _get_type_text(tipo: Mision.Tipo) -> String:
		match tipo:
			Mision.Tipo.HISTORIA: return "Historia"
			Mision.Tipo.SECUNDARIA: return "Secundaria"
			Mision.Tipo.EVENTO: return "Evento"
			Mision.Tipo.DIARIA: return "Diaria"
		return "-"

class ColorInterfaz:
	enum UI {
		VERDE_FLUORESCENTE,
		BLANCO_FONDO,
		BLANCO_LINEA,

		NEGRO,
		AZUL,
		CIAN,
		VERDE,
		PURPURA,
		ROJO,
		BLANCO,
		AMARILLO,
		NEGRO_BRILLANTE,
		AZUL_BRILLANTE,
		CIAN_BRILLANTE,
		VERDE_BRILLANTE,
		PURPURA_BRILLANTE,
		ROJO_BRILLANTE,
		BLANCO_BRILLANTE,
		AMARILLO_BRILLANTE
	}

	const valor_color_ui := {
		UI.VERDE_FLUORESCENTE: "38ff14",
		UI.BLANCO_FONDO: "f0f0f0",
		UI.BLANCO_LINEA: "eaeaea10",

		UI.NEGRO: "0C0C0C",
		UI.AZUL: "0037DA",
		UI.CIAN: "3A96DD",
		UI.VERDE: "13A10E",
		UI.PURPURA: "881798",
		UI.ROJO: "C50F1F",
		UI.BLANCO: "CCCCCC",
		UI.AMARILLO: "C19C00",
		UI.NEGRO_BRILLANTE: "767676",
		UI.AZUL_BRILLANTE: "3B78FF",
		UI.CIAN_BRILLANTE: "61D6D6",
		UI.VERDE_BRILLANTE: "16C60C",
		UI.PURPURA_BRILLANTE: "B4009E",
		UI.ROJO_BRILLANTE: "E74856",
		UI.BLANCO_BRILLANTE: "F2F2F2",
		UI.AMARILLO_BRILLANTE: "F9F1A5"
	}
