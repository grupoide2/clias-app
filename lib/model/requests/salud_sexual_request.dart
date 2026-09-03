class SaludSexualRequest {
  bool estaEmbarazada = false;
  String? fechaUltimaMenstruacion;
  String? ultimoExamenPap;
  String? tiempoPruebaVph;
  int? numParejasSexuales;
  String? tieneEts;
  String? nombreEts;
  String? estaMenstruando;

  SaludSexualRequest(
      this.estaEmbarazada,
      this.fechaUltimaMenstruacion,
      this.ultimoExamenPap,
      this.tiempoPruebaVph,
      this.numParejasSexuales,
      this.tieneEts,
      this.nombreEts,
      {this.estaMenstruando}); // "SI" o "NO"

  // Cada pregunta tiene su propio catálogo (rango_tiempo_examen filtrado por
  // `pregunta`); los códigos llevan prefijo PAP_ / VPH_. El código real llega
  // desde el `payload` de assets/offline_form.json.
  Map<String, String> rangoTiempoPap = {
    "Menos de 1 año": "PAP_MENOS_1_ANIO",
    "De 1 a 3 años": "PAP_1_A_3_ANIOS",
    "Más 3 años": "PAP_MAS_3_ANIOS",
    "Nunca": "PAP_NUNCA"
  };

  Map<String, String> rangoTiempoVph = {
    "Menos de 1 año": "VPH_MENOS_1_ANIO",
    "De 1 a 3 años": "VPH_1_A_3_ANIOS",
    "Más 3 años": "VPH_MAS_3_ANIOS",
    "Nunca": "VPH_NUNCA"
  };

  Map<String, String> opciones = {"No": "NO", "Nose": "NOSE", "Si": "SI"};

  static final Map<String, String> opcionesReverse = {"NO": "No", "NOSE": "Nose", "SI": "Si"};

  factory SaludSexualRequest.fromJson(Map<String, dynamic> json) {
    return SaludSexualRequest(
        json["estaEmbarazada"],
        json["fechaUltimaMenstruacion"],
        json["ultimoExamenPap"],
        json["tiempoPruebaVph"],
        json["numParejasSexuales"],
        opcionesReverse[json["tieneEts"]],
        json["nombreEts"],
        estaMenstruando: json["estaMenstruando"]);
  }

  Map<String, dynamic> toJson() {
    return {
      "estaEmbarazada": estaEmbarazada,
      "fechaUltimaMenstruacion": fechaUltimaMenstruacion,
      "ultimoExamenPap": ultimoExamenPap,
      "tiempoPruebaVph": tiempoPruebaVph,
      "numParejasSexuales": numParejasSexuales,
      "tieneEts": opciones[tieneEts],
      "nombreEts": nombreEts,
      "estaMenstruando": estaMenstruando,
    };
  }
}
