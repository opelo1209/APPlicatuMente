// PROTOTIPO Semana 8 (pregunta 13 de la Dra. González): los 10 textos que
// rechazó en su revisión del material salen de la app hasta tener una
// versión corregida. Serena ya no los citaba (revision_clinica.py); ahora
// tampoco los muestran los módulos. Los identificadores son los mismos de la
// revisión clínica (textos_rechazados.pdf, Semana 7).

const Set<String> textosRetirados = {
  'autolesiones.actionContent.adolescente',
  'autolesiones.actionContent.familia',
  'suicidio.bloque1Content.adolescente',
  'suicidio.quimicaDesc.adolescente',
  'suicidio.quimicaDesc.familia',
  'suicidio.estresDesc.familia',
  'autolesiones.teenImgAdvertencia.adolescente',
  'autolesiones.teenImgQueHacer.adolescente',
  'suicidio.teenImgQuimicaCerebro.adolescente',
  'suicidio.teenImgEstres.adolescente',
};

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
