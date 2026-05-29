import '../models/card_data.dart';

List<CardData> createCardPool() {
  return [
    // Cognitivo - attack 2-4
    CardData(id: 'cog_01', name: 'Checar las Pruebas', imagePath: 'tcg0.jpg', attack: 3, type: CardType.cognitivo),
    CardData(id: 'cog_02', name: 'Pensamiento Alterno', imagePath: 'tcg1.jpg', attack: 4, type: CardType.cognitivo),
    CardData(id: 'cog_03', name: 'Ponerle Nombre', imagePath: 'tcg2.jpg', attack: 2, type: CardType.cognitivo),
    CardData(id: 'cog_04', name: 'Diario Rápido', imagePath: 'tcg3.jpg', attack: 3, type: CardType.cognitivo),
    CardData(id: 'cog_05', name: 'Frase Ancla', imagePath: 'tcg4.jpg', attack: 3, type: CardType.cognitivo),
    CardData(id: 'cog_06', name: 'Reencuadre', imagePath: 'tcg5.jpg', attack: 4, type: CardType.cognitivo),
    CardData(id: 'cog_07', name: 'Mapa Mental', imagePath: 'tcg6.jpg', attack: 2, type: CardType.cognitivo),
    CardData(id: 'cog_08', name: 'Escalera Lógica', imagePath: 'tcg7.jpg', attack: 3, type: CardType.cognitivo),
    CardData(id: 'cog_09', name: 'Detener el Pensamiento', imagePath: 'tcg8.jpg', attack: 4, type: CardType.cognitivo),
    CardData(id: 'cog_10', name: 'Examen de Realidad', imagePath: 'tcg9.jpg', attack: 3, type: CardType.cognitivo),
    CardData(id: 'cog_11', name: 'Flexibilidad Mental', imagePath: 'tcg10.jpg', attack: 4, type: CardType.cognitivo),
    CardData(id: 'cog_12', name: 'Organizar Ideas', imagePath: 'tcg11.jpg', attack: 2, type: CardType.cognitivo),
    CardData(id: 'cog_13', name: 'Análisis Objetivo', imagePath: 'tcg12.jpg', attack: 3, type: CardType.cognitivo),
    CardData(id: 'cog_14', name: 'Perspectiva', imagePath: 'tcg13.jpg', attack: 4, type: CardType.cognitivo),

    // Emocional - attack 2-5
    CardData(id: 'emo_15', name: 'Nombrar la Emoción', imagePath: 'tcg14.jpg', attack: 3, type: CardType.emocional),
    CardData(id: 'emo_16', name: 'Darse Chance de Sentir', imagePath: 'tcg16.jpg', attack: 3, type: CardType.emocional),
    CardData(id: 'emo_17', name: 'Respirar 4 Tiempos', imagePath: 'tcg17.jpg', attack: 2, type: CardType.emocional),
    CardData(id: 'emo_18', name: 'Anclaje Sensorial', imagePath: 'tcg18.jpg', attack: 3, type: CardType.emocional),
    CardData(id: 'emo_19', name: 'Hablarlo con Alguien', imagePath: 'tcg19.jpg', attack: 5, type: CardType.emocional),
    CardData(id: 'emo_20', name: 'Auto-compasión', imagePath: 'tcg20.jpg', attack: 4, type: CardType.emocional),
    CardData(id: 'emo_21', name: 'Validación Emocional', imagePath: 'tcg21.jpg', attack: 3, type: CardType.emocional),
    CardData(id: 'emo_22', name: 'Liberar Tensión', imagePath: 'tcg22.jpg', attack: 2, type: CardType.emocional),
    CardData(id: 'emo_23', name: 'Gratitud', imagePath: 'tcg23.jpg', attack: 4, type: CardType.emocional),
    CardData(id: 'emo_24', name: 'Aceptación', imagePath: 'tcg24.jpg', attack: 3, type: CardType.emocional),
    CardData(id: 'emo_25', name: 'Equilibrio', imagePath: 'tcg25.jpg', attack: 4, type: CardType.emocional),
    CardData(id: 'emo_26', name: 'Liberar Emociones', imagePath: 'tcg26.jpg', attack: 5, type: CardType.emocional),

    // Conductual - attack 2-5
    CardData(id: 'con_27', name: 'Un Paso Pequeño', imagePath: 'tcg27.jpg', attack: 2, type: CardType.conductual),
    CardData(id: 'con_28', name: 'Plan de Mini-Metas', imagePath: 'tcg28.jpg', attack: 4, type: CardType.conductual),
    CardData(id: 'con_29', name: 'Actividad que Disfruto', imagePath: 'tcg29.jpg', attack: 3, type: CardType.conductual),
    CardData(id: 'con_30', name: 'Higiene de Sueño', imagePath: 'tcg30.jpg', attack: 3, type: CardType.conductual),
    CardData(id: 'con_31', name: 'Pedir Ayuda', imagePath: 'tcg31.jpg', attack: 5, type: CardType.conductual),
    CardData(id: 'con_32', name: 'Rutina Positiva', imagePath: 'tcg32.jpg', attack: 4, type: CardType.conductual),
    CardData(id: 'con_33', name: 'Actividad Física', imagePath: 'tcg33.jpg', attack: 3, type: CardType.conductual),
    CardData(id: 'con_34', name: 'Descanso Activo', imagePath: 'tcg34.jpg', attack: 2, type: CardType.conductual),
    CardData(id: 'con_35', name: 'Exposición Gradual', imagePath: 'tcg35.jpg', attack: 4, type: CardType.conductual),
    CardData(id: 'con_36', name: 'Recompensa', imagePath: 'tcg36.jpg', attack: 3, type: CardType.conductual),
    CardData(id: 'con_37', name: 'Ritmo Constante', imagePath: 'tcg37.jpg', attack: 4, type: CardType.conductual),
    CardData(id: 'con_38', name: 'Desconexión', imagePath: 'tcg38.jpg', attack: 2, type: CardType.conductual),
    CardData(id: 'con_39', name: 'Logro Diario', imagePath: 'tcg39.jpg', attack: 3, type: CardType.conductual),
    CardData(id: 'con_40', name: 'Celebrar Progreso', imagePath: 'tcg40.jpg', attack: 4, type: CardType.conductual),
  ];
}
