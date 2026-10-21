import 'dart:convert';
import 'life_workspace.dart';

const lifePacks = {
  'foundations': (
    'Personal foundations',
    'A goal, one flexible habit, a morning routine, a daily journal and a connected board.',
  ),
  'training': (
    'Training notebook',
    'Your named exercises, a reusable workout, a multiweek program and a linked board. No prescribed training advice.',
  ),
  'learning': (
    'Learning sprint',
    'A skill roadmap, practice habit, learning goal and a connected workspace for evidence.',
  ),
  'home': (
    'Home reset',
    'Meal planning, groceries, maintenance and an ordered weekly reset routine.',
  ),
  'outdoors': (
    'Outdoor and nature journal',
    'A trip plan, field journal and observation goal beside a connected board.',
  ),
};

class LifePackResult {
  const LifePackResult(this.ids, {this.boardId, this.error});
  final List<String> ids;
  final String? boardId, error;
  bool get complete => boardId != null && error == null;
}

class LifePreset {
  const LifePreset(
    this.id,
    this.title,
    this.kind,
    this.description,
    this.body, [
    this.fields = const {},
  ]);
  final String id, title, description, body;
  final LifeKind kind;
  final Map<String, dynamic> fields;
}

const lifePresets = <LifePreset>[
  LifePreset(
    'goal',
    'A meaningful goal',
    LifeKind.goal,
    'Outcome, reason, milestones and evidence.',
    '## Why this matters\n\n## What success looks like\n\n## Obstacles and a smaller first step\n\n## Evidence and reflections\n',
    {'progressMode': 'actions'},
  ),
  LifePreset(
    'reading',
    'Reading habit',
    LifeKind.habit,
    'Track pages without treating missed tracking as failure.',
    '## My cue\nAfter…\n\n## Minimum version\nRead one page.\n\n## What helps\n',
    {'frequency': 'daily', 'target': 10, 'minimum': 1, 'unit': 'pages'},
  ),
  LifePreset(
    'movement',
    'Movement habit',
    LifeKind.habit,
    'Choose your own comfortable amount and schedule.',
    '## My cue and place\n\n## Minimum version\n\n## Adaptations\n',
    {
      'frequency': 'weekdays',
      'weekdays': [1, 3, 5],
      'target': 1,
      'minimum': 1,
      'unit': 'sessions',
    },
  ),
  LifePreset(
    'weekly',
    'Weekly practice',
    LifeKind.habit,
    'A weekly quantity rather than a daily streak.',
    '## Why I practice\n\n## Make it easier\n',
    {'frequency': 'weekly', 'target': 3, 'minimum': 1, 'unit': 'sessions'},
  ),
  LifePreset(
    'morning',
    'Morning routine',
    LifeKind.routine,
    'An ordered checklist with a separate record each day.',
    '## A calm start\nAdjust these steps to your own needs.\n',
    {
      'items': [
        'Check today’s commitments',
        'Choose one priority',
        'Prepare what I need',
      ],
    },
  ),
  LifePreset(
    'shutdown',
    'Evening shutdown',
    LifeKind.routine,
    'Close open loops and prepare tomorrow.',
    '## What can wait until tomorrow?\n',
    {
      'items': [
        'Capture loose thoughts',
        'Review tomorrow’s calendar',
        'Choose a stopping point',
      ],
    },
  ),
  LifePreset(
    'exercise',
    'Exercise library entry',
    LifeKind.exercise,
    'Your instructions, equipment, alternatives and linked references.',
    '## Instructions\n\n## Equipment\n\n## Substitutions\n\n## Personal notes\n',
  ),
  LifePreset(
    'workout',
    'Custom workout',
    LifeKind.workout,
    'Choose exercises from your library and log your own session.',
    '## Purpose\n\n## Preparation\n\n## Adaptations\n',
    {
      'setsPerExercise': 3,
      'restSeconds': 90,
      'weightUnit': 'kg',
      'distanceUnit': 'km',
    },
  ),
  LifePreset(
    'program',
    'Training calendar',
    LifeKind.program,
    'Schedule your chosen workouts on selected weekdays.',
    '## Purpose and constraints\n\n## How I will adjust\n',
    {
      'weekCount': 4,
      'weekdays': [1, 3, 5],
      'minutes': 60,
    },
  ),
  LifePreset(
    'daily',
    'Daily journal',
    LifeKind.journal,
    'Intentions, observations and an evening reflection.',
    '## Today’s intention\n\n## Free writing\n\n## What happened\n\n## Something I appreciate\n\n## Tomorrow\n',
  ),
  LifePreset(
    'gratitude',
    'Gratitude and small wins',
    LifeKind.journal,
    'A low-pressure record of things worth remembering.',
    '## Something I appreciated\n\n## A small win\n\n## Someone to thank\n',
  ),
  LifePreset(
    'decision',
    'Personal decision',
    LifeKind.journal,
    'Alternatives, uncertainty, reasoning and a review date.',
    '## The decision\n\n## Alternatives\n\n## What I know and do not know\n\n## My reasoning\n\n## When to revisit\n',
  ),
  LifePreset(
    'achievement',
    'Achievement log',
    LifeKind.journal,
    'Keep evidence of progress and lessons learned.',
    '## What I completed\n\n## Evidence\n\n## What I learned\n\n## Who helped\n',
  ),
  LifePreset(
    'nature',
    'Nature field journal',
    LifeKind.journal,
    'Place, weather, observations and sketches or photos.',
    '## Place and conditions\n\n## What I noticed\n\n## Photos, sketches and observations\n\n## Leave-no-trace reflection\n',
  ),
  LifePreset(
    'travel-journal',
    'Travel journal',
    LifeKind.journal,
    'Experiences, places and memories.',
    '## Where I went\n\n## Moments to remember\n\n## People and discoveries\n\n## Photos and references\n',
  ),
  LifePreset(
    'experiment',
    'Personal experiment',
    LifeKind.experiment,
    'Baseline, one change, measurements and an honest conclusion.',
    '## Question and reason\n\n## Baseline\n\n## One change to try\n\n## Measurement and limitations\n\n## Dated observations\n\n## Outcome: continue, adapt or stop?\n',
    {'baseline': 0, 'target': 1, 'value': 0, 'unit': 'observations'},
  ),
  LifePreset(
    'checkin',
    'Optional daily check-in',
    LifeKind.checkin,
    'Only record what you choose; gaps remain unknown.',
    '## Context I want to remember\n\n## What might help today\n',
  ),
  LifePreset(
    'skill',
    'Skill roadmap',
    LifeKind.skill,
    'Practice, evidence, resources and linked learning steps.',
    '## Why this skill\n\n## Starting point\n\n## Roadmap\n\n## Self-assessment\n\n## Portfolio evidence\n',
    {'progressMode': 'actions'},
  ),
  LifePreset(
    'practice',
    'Deliberate practice',
    LifeKind.practice,
    'A dated session linked to a skill, course or goal.',
    '## What I practiced\n\n## Feedback and difficulties\n\n## Evidence\n\n## Next practice\n',
    {'minutes': 25},
  ),
  LifePreset(
    'reading-plan',
    'Reading and learning plan',
    LifeKind.skill,
    'Resources, reading notes, practice and portfolio work.',
    '## Learning outcome\n\n## Reading queue\n\n## Notes and questions\n\n## Apply what I learn\n\n## Evidence\n',
  ),
  LifePreset(
    'meal',
    'Meal and recipe plan',
    LifeKind.life,
    'Recipes, ingredients and a checkable grocery list.',
    '## Meals this week\n\n## Recipes and portions\n\n## Preparation notes\n',
    {
      'category': 'Meals',
      'items': ['Check pantry', 'Choose meals', 'Write grocery list'],
    },
  ),
  LifePreset(
    'recipe',
    'Recipe library',
    LifeKind.life,
    'Ingredients, quantities, method and personal variations.',
    '## Servings and preparation time\n\n## Ingredients\n\n## Method\n\n## Variations and source\n',
    {'category': 'Recipes'},
  ),
  LifePreset(
    'groceries',
    'Grocery list',
    LifeKind.life,
    'Check items off; keep quantities and shops in the item text.',
    '## Shops and notes\n',
    {
      'category': 'Groceries',
      'items': ['Vegetables', 'Pantry items', 'Household supplies'],
    },
  ),
  LifePreset(
    'home',
    'Home maintenance',
    LifeKind.life,
    'Supplies, instructions, service history and actual reminders.',
    '## Item and location\n\n## Instructions and documents\n\n## Service history\n\n## Next maintenance\n',
    {'category': 'Home'},
  ),
  LifePreset(
    'renewal',
    'Renewal and important document',
    LifeKind.life,
    'Record a deadline and link the original document.',
    '## Document or subscription\n\n## Location and references\n\n## Renewal details\n\n## Next action\n',
    {'category': 'Documents'},
  ),
  LifePreset(
    'appointment',
    'Appointment preparation',
    LifeKind.life,
    'Questions, resources, appointment and follow-up tasks.',
    '## Purpose\n\n## Questions\n\n## What to bring\n\n## Notes and follow-up\n',
    {'category': 'Appointments'},
  ),
  LifePreset(
    'trip',
    'Trip and outdoor plan',
    LifeKind.life,
    'Route, transport, accommodation, kit and contingency.',
    '## Destination and purpose\n\n## Itinerary and route\n\n## Weather, conditions and contingency\n\n## Transport and accommodation\n\n## References\n',
    {
      'category': 'Travel',
      'items': [
        'Check conditions',
        'Confirm route and transport',
        'Pack essentials',
        'Share itinerary if appropriate',
      ],
    },
  ),
  LifePreset(
    'inventory',
    'Personal inventory',
    LifeKind.life,
    'Equipment, location, condition, documents and maintenance.',
    '## Inventory\n\n| Item | Location | Condition | Reference |\n| --- | --- | --- | --- |\n| | | | |\n\n## Maintenance and replacements\n',
    {'category': 'Inventory'},
  ),
  LifePreset(
    'people',
    'People and follow-ups',
    LifeKind.life,
    'Remember conversations, shared plans and thoughtful follow-ups.',
    '## Person and context\n\n## Conversation notes\n\n## Shared plans\n\n## Follow-up\n',
    {'category': 'People'},
  ),
  LifePreset(
    'event',
    'Personal event',
    LifeKind.life,
    'Plan an occasion with a calendar event and linked actions.',
    '## Occasion and date\n\n## People and location\n\n## Budget and arrangements\n',
    {
      'category': 'Events',
      'items': [
        'Choose date and place',
        'Confirm arrangements',
        'Prepare what is needed',
      ],
    },
  ),
  LifePreset(
    'vision',
    'Life direction and values',
    LifeKind.life,
    'A considered vision linked to real goals and evidence.',
    '## What matters to me\n\n## Areas of life\n\n## What I want more of\n\n## What I want less of\n\n## Goals and experiments\n',
    {'category': 'Reflection'},
  ),
];

/// Clone known spatial identities only. Canonical object and opaque future IDs
/// remain unchanged; a new board still points to the same knowledge objects.
Map<String, dynamic> remapLifeCanvas(
  Map<String, dynamic> source,
  String Function() nextId,
) {
  final copy = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  if (copy['elements'] is! List) {
    throw const FormatException('The saved layout has no element list.');
  }
  final elements = copy['elements'] as List;
  final ids = <String, String>{},
      groups = <String, String>{},
      used = <String>{};
  String fresh() {
    final id = nextId();
    if (id.isEmpty || !used.add(id)) {
      throw StateError('Template IDs must be unique.');
    }
    return id;
  }

  for (final raw in elements) {
    if (raw is! Map || raw['id'] is! String || ids.containsKey(raw['id'])) {
      throw const FormatException('Invalid saved placement identity.');
    }
    ids[raw['id'] as String] = fresh();
    if (raw['groupId'] is String) {
      groups.putIfAbsent(raw['groupId'] as String, fresh);
    }
  }
  for (final raw in elements) {
    final e = raw as Map;
    e['id'] = ids[e['id']];
    for (final key in [
      'startId',
      'endId',
      'parentId',
      'columnId',
      'sectionId',
    ]) {
      if (ids.containsKey(e[key])) e[key] = ids[e[key]];
    }
    if (groups.containsKey(e['groupId'])) e['groupId'] = groups[e['groupId']];
  }
  return copy;
}
