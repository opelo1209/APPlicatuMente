import 'tutor_step.dart';

List<TutorStep> createTutorialSteps() {
  return [
    const TutorStep(
      id: 'welcome',
      instruction: 'Bienvenido al TCG Salud Mental',
      detail:
          'Aprenderás lo básico en pocos pasos. Cada carta representa una '
          'herramienta de salud mental que puedes usar para vencer pensamientos negativos.',
      highlight: TutorHighlightTarget.wholeBoard,
      requiredAction: TutorAction.tap,
    ),
    const TutorStep(
      id: 'hand',
      instruction: 'Tus cartas están aquí abajo',
      detail:
          'Cada carta tiene un tipo (Cognitivo, Emocional, Conductual) y un '
          'valor de Ataque (ATK). Arrástralas al slot central para jugarlas.',
      highlight: TutorHighlightTarget.hand,
      requiredAction: TutorAction.tap,
    ),
    const TutorStep(
      id: 'slot',
      instruction: 'Este es el slot central',
      detail:
          'Es el único lugar donde se colocan las cartas. Cuando arrastres '
          'una carta aquí, se enfrentará a la carta del oponente.',
      highlight: TutorHighlightTarget.playerSlot,
      requiredAction: TutorAction.tap,
    ),
    const TutorStep(
      id: 'energy',
      instruction: 'La energía es tu recurso',
      detail:
          'La barra superior muestra tu energía disponible. Jugar una carta '
          'cuesta 2 de energía. Cada turno recibes más energía.',
      highlight: TutorHighlightTarget.energyBar,
      requiredAction: TutorAction.tap,
    ),
    const TutorStep(
      id: 'play_card',
      instruction: 'Arrastra una carta al slot central',
      detail:
          'Toca y arrastra cualquiera de tus cartas hacia el slot iluminado. '
          'Inténtalo ahora.',
      highlight: TutorHighlightTarget.hand,
      requiredAction: TutorAction.dropCard,
    ),
    const TutorStep(
      id: 'combat',
      instruction: '¡Combate en acción!',
      detail:
          'Cuando ambas cartas están colocadas, el combate ocurre '
          'automáticamente. Ambas cartas se descartan después.',
      highlight: TutorHighlightTarget.playerSlot,
      requiredAction: TutorAction.observe,
      autoAdvance: true,
    ),
    const TutorStep(
      id: 'turns',
      instruction: 'Los turnos alternan',
      detail:
          'Tú colocas una carta, luego el enemigo. El turno cambia después '
          'de cada combate. Siempre recibirás energía al inicio de tu turno.',
      highlight: TutorHighlightTarget.energyBar,
      requiredAction: TutorAction.tap,
    ),
    const TutorStep(
      id: 'win_condition',
      instruction: '¿Cómo ganar o perder?',
      detail:
          'Cada jugador tiene 25 HP (vida). Cuando el HP de alguien llega '
          'a 0, la partida termina. ¡Usa bien tus cartas para protegerte!',
      highlight: TutorHighlightTarget.wholeBoard,
      requiredAction: TutorAction.tap,
    ),
    const TutorStep(
      id: 'complete',
      instruction: '¡Tutorial completado!',
      detail:
          'Ahora juega con confianza. Puedes volver a ver este tutorial '
          'cuando quieras desde el menú del juego.',
      highlight: TutorHighlightTarget.none,
      requiredAction: TutorAction.tap,
    ),
  ];
}
