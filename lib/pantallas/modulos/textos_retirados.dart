// PROTOTIPO Semana 8 (pregunta 13 de la Dra. González): los 10 textos que
// rechazó en su revisión del material salieron de la app hasta tener una
// versión corregida. Los identificadores son los mismos de la revisión
// clínica (textos_rechazados.pdf, Semana 7).
//
// Semana 9: la Dra. revisó los 10 (Anexo A, 17 de noviembre). Cuatro se
// quedan y seis cambian de texto (textos_revision_dra.dart), así que ya no
// hay ninguno retirado. El mecanismo se conserva para la próxima revisión.

const Set<String> textosRetirados = {};

bool estaRetirado(String id) => textosRetirados.contains(id);

/// Audiencia de los identificadores: `adolescente` o `familia`.
String audiencia({required bool paraAdolescentes}) =>
    paraAdolescentes ? 'adolescente' : 'familia';

/// Une con una línea en blanco los textos que no están retirados.
String unirVisibles(List<(String, String)> partes) => [
  for (final (id, texto) in partes)
    if (!estaRetirado(id) && texto.isNotEmpty) texto,
].join('\n\n');

/// Deja solo los elementos cuyo identificador no está retirado.
List<T> sinRetirados<T>(List<(String, T)> elementos) => [
  for (final (id, elemento) in elementos)
    if (!estaRetirado(id)) elemento,
];
