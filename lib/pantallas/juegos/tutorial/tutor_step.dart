import 'package:flutter/material.dart';

enum TutorAction { tap, dropCard, observe }

enum TutorHighlightTarget {
  none,
  playerSlot,
  enemySlot,
  hand,
  energyBar,
  combatResolve,
  wholeBoard,
}

class TutorStep {
  final String id;
  final String instruction;
  final String? detail;
  final TutorAction requiredAction;
  final TutorHighlightTarget highlight;
  final Alignment instructionAlign;
  final bool autoAdvance;

  const TutorStep({
    required this.id,
    required this.instruction,
    this.detail,
    this.requiredAction = TutorAction.tap,
    this.highlight = TutorHighlightTarget.none,
    this.instructionAlign = Alignment.bottomCenter,
    this.autoAdvance = false,
  });
}
