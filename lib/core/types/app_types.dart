enum CommunicationLevel {
  reactive,
  understandable,
  structured,
  managerReady,
  directorReady,
  executiveReady,
  ceoLevel,
}

enum Pillar {
  clarity,
  structure,
  brevity,
  presence,
  strategicFraming,
  pressureResponse,
}

enum PromptCategory {
  blufStructuredThinking,
  directAnswerDiscipline,
  brevityCompression,
  executivePresence,
  strategicFraming,
  pressureResponse,
  listeningSummarization,
}

enum RecalibrationState { accelerating, stable, plateau, regressing }

enum SessionStatus { inProgress, completed }

enum PlanItemStatus { scheduled, completed, missed, skipped }

enum ResponseMode { typed, audio }

enum RetryOutcome { improved, noChange, regressed }

enum SeniorityBand {
  emergingManager,
  manager,
  seniorManager,
  director,
  vicePresident,
  founder,
}

enum SessionOrigin { baseline, dailyPlan }

extension CommunicationLevelX on CommunicationLevel {
  String get label => switch (this) {
    CommunicationLevel.reactive => 'Reactive',
    CommunicationLevel.understandable => 'Understandable',
    CommunicationLevel.structured => 'Structured',
    CommunicationLevel.managerReady => 'Manager-ready',
    CommunicationLevel.directorReady => 'Director-ready',
    CommunicationLevel.executiveReady => 'Executive-ready',
    CommunicationLevel.ceoLevel => 'CEO-level',
  };
}

extension PillarX on Pillar {
  String get label => switch (this) {
    Pillar.clarity => 'Clarity',
    Pillar.structure => 'Structure',
    Pillar.brevity => 'Brevity',
    Pillar.presence => 'Presence',
    Pillar.strategicFraming => 'Strategic framing',
    Pillar.pressureResponse => 'Pressure response',
  };
}

extension PromptCategoryX on PromptCategory {
  String get label => switch (this) {
    PromptCategory.blufStructuredThinking => 'BLUF / Structure',
    PromptCategory.directAnswerDiscipline => 'Direct answer',
    PromptCategory.brevityCompression => 'Brevity',
    PromptCategory.executivePresence => 'Executive presence',
    PromptCategory.strategicFraming => 'Strategic framing',
    PromptCategory.pressureResponse => 'Pressure response',
    PromptCategory.listeningSummarization => 'Listening / Summary',
  };
}

extension RecalibrationStateX on RecalibrationState {
  String get label => switch (this) {
    RecalibrationState.accelerating => 'Accelerating',
    RecalibrationState.stable => 'Stable',
    RecalibrationState.plateau => 'Plateau',
    RecalibrationState.regressing => 'Regressing',
  };
}

extension ResponseModeX on ResponseMode {
  String get label => switch (this) {
    ResponseMode.typed => 'Typed response',
    ResponseMode.audio => 'Audio response',
  };
}

extension SeniorityBandX on SeniorityBand {
  String get label => switch (this) {
    SeniorityBand.emergingManager => 'Emerging manager',
    SeniorityBand.manager => 'Manager',
    SeniorityBand.seniorManager => 'Senior manager',
    SeniorityBand.director => 'Director',
    SeniorityBand.vicePresident => 'VP / Executive',
    SeniorityBand.founder => 'Founder',
  };
}
