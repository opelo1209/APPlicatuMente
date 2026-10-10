// PROTOTIPO (Semana 2): catálogo del semáforo de ánimo del diario.
//
// Es el espejo de mock_backend/app/emociones_catalogo.py: si se cambia uno
// hay que cambiar el otro. El backend vuelve a validar todo lo que llega.
import 'package:flutter/material.dart';

enum Polaridad { positivo, neutro, negativo }

class PolaridadInfo {
  const PolaridadInfo({
    required this.polaridad,
    required this.nombre,
    required this.pregunta,
    required this.color,
    required this.icono,
  });

  final Polaridad polaridad;
  final String nombre;
  final String pregunta;
  final Color color;
  final IconData icono;
}

// El negativo es coral y no rojo de alarma: un día difícil no es una
// emergencia. La paleta final es decisión clínica (ver reporte).
const Map<Polaridad, PolaridadInfo> kPolaridades = {
  Polaridad.positivo: PolaridadInfo(
    polaridad: Polaridad.positivo,
    nombre: 'Positivo',
    pregunta: '¿Qué hizo bueno tu día?',
    color: Color(0xFF43A047),
    icono: Icons.sentiment_very_satisfied_rounded,
  ),
  Polaridad.neutro: PolaridadInfo(
    polaridad: Polaridad.neutro,
    nombre: 'Neutro',
    pregunta: '¿Cómo describirías tu día?',
    color: Color(0xFFF9A825),
    icono: Icons.sentiment_neutral_rounded,
  ),
  Polaridad.negativo: PolaridadInfo(
    polaridad: Polaridad.negativo,
    nombre: 'Negativo',
    pregunta: '¿Qué hizo difícil tu día?',
    color: Color(0xFFE8664F),
    icono: Icons.sentiment_dissatisfied_rounded,
  ),
};

Polaridad polaridadDesdeTexto(String valor) => Polaridad.values.firstWhere(
  (p) => p.name == valor,
  orElse: () => Polaridad.neutro,
);

class EmocionOpcion {
  const EmocionOpcion(this.clave, this.nombre, this.polaridad);
  final String clave;
  final String nombre;
  final Polaridad polaridad;
}

const List<EmocionOpcion> kEmociones = [
  EmocionOpcion('alegria', 'Alegría', Polaridad.positivo),
  EmocionOpcion('felicidad', 'Felicidad', Polaridad.positivo),
  EmocionOpcion('calma', 'Calma', Polaridad.positivo),
  EmocionOpcion('gratitud', 'Gratitud', Polaridad.positivo),
  EmocionOpcion('orgullo', 'Orgullo', Polaridad.positivo),
  EmocionOpcion('entusiasmo', 'Entusiasmo', Polaridad.positivo),
  EmocionOpcion('carino', 'Cariño', Polaridad.positivo),
  EmocionOpcion('esperanza', 'Esperanza', Polaridad.positivo),
  EmocionOpcion('tranquilidad', 'Tranquilidad', Polaridad.neutro),
  EmocionOpcion('cansancio', 'Cansancio', Polaridad.neutro),
  EmocionOpcion('aburrimiento', 'Aburrimiento', Polaridad.neutro),
  EmocionOpcion('confusion', 'Confusión', Polaridad.neutro),
  EmocionOpcion('sorpresa', 'Sorpresa', Polaridad.neutro),
  EmocionOpcion('indiferencia', 'Indiferencia', Polaridad.neutro),
  EmocionOpcion('nostalgia', 'Nostalgia', Polaridad.neutro),
  EmocionOpcion('tristeza', 'Tristeza', Polaridad.negativo),
  EmocionOpcion('angustia', 'Angustia', Polaridad.negativo),
  EmocionOpcion('ansiedad', 'Ansiedad', Polaridad.negativo),
  EmocionOpcion('miedo', 'Miedo', Polaridad.negativo),
  EmocionOpcion('ira', 'Ira / enojo', Polaridad.negativo),
  EmocionOpcion('frustracion', 'Frustración', Polaridad.negativo),
  EmocionOpcion('soledad', 'Soledad', Polaridad.negativo),
  EmocionOpcion('culpa', 'Culpa', Polaridad.negativo),
  EmocionOpcion('verguenza', 'Vergüenza', Polaridad.negativo),
  EmocionOpcion('asco', 'Asco', Polaridad.negativo),
];

List<EmocionOpcion> emocionesDe(Polaridad p) =>
    kEmociones.where((e) => e.polaridad == p).toList(growable: false);

// Nombres de las 7 clases del analizador (pysentimiento), para mostrar.
const Map<String, String> kClasesAnalizador = {
  'alegria': 'Alegría',
  'tristeza': 'Tristeza',
  'enojo': 'Enojo',
  'miedo': 'Miedo / angustia',
  'sorpresa': 'Sorpresa',
  'asco': 'Asco / rechazo',
  'otra': 'Otras',
};

class LineaAyuda {
  const LineaAyuda(this.nombre, this.telefono, this.horario);
  final String nombre;
  final String telefono;
  final String horario;
}

// Pendiente de confirmar con la doctora (revisión clínica, apartado A).
const List<LineaAyuda> kLineasAyuda = [
  LineaAyuda('Línea de la Vida', '800 911 2000', '24 horas, gratuita'),
  LineaAyuda('SAPTEL', '55 5259 8121', '24 horas'),
];
