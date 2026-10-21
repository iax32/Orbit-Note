import 'geometry.dart';
import 'scene.dart';

class CanvasStarter {
  const CanvasStarter({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    required this.prompts,
    this.mindMap = false,
  });
  final String id, name, description;
  final List<String> tags;
  final List<({String title, String prompt})> prompts;
  final bool mindMap;

  /// Fresh placement IDs on every insertion; no fake universal objects or locks.
  List<CanvasElement> createElements(String Function() idGenerator) {
    final used = <String>{};
    String id() {
      final next = idGenerator();
      if (next.isEmpty || !used.add(next)) {
        throw StateError('A starter needs unique placement IDs.');
      }
      return next;
    }

    const accents = [
      0xff8b7cf6,
      0xff65b69b,
      0xffc4a778,
      0xff7e9fc6,
      0xffbd8f9e,
      0xff90ac84,
    ];
    final root = CanvasElement({
      'id': id(),
      'type': mindMap ? 'sticky' : 'section',
      'x': mindMap ? -130.0 : -490.0,
      'y': mindMap ? -70.0 : -310.0,
      'width': mindMap ? 260.0 : 980.0,
      'height': mindMap ? 140.0 : 48.0,
      'text': mindMap ? '$name\n\nWrite your central question here.' : name,
      'color': accents.first,
      'fontSize': mindMap ? 18.0 : 24.0,
    });
    final nodes = <CanvasElement>[];
    final edges = <CanvasElement>[];
    for (var i = 0; i < prompts.length; i++) {
      final prompt = prompts[i];
      final point = mindMap
          ? CanvasPoint(i.isEven ? -490 : 210, (i ~/ 2) * 230.0 - 310)
          : CanvasPoint((i % 3) * 340.0 - 490, (i ~/ 3) * 250.0 - 240);
      final node = CanvasElement({
        'id': id(),
        'type': 'sticky',
        'x': point.x,
        'y': point.y,
        'width': 300.0,
        'height': 210.0,
        'text': '${prompt.title}\n\n${prompt.prompt}',
        'fontSize': 16.0,
        'color': accents[i % accents.length],
      });
      nodes.add(node);
      if (mindMap) {
        edges.add(
          CanvasElement({
            'id': id(),
            'type': 'connector',
            'startId': root.id,
            'endId': node.id,
            'color': accents[i % accents.length],
            'strokeWidth': 2.0,
            'endMarker': 'none',
            'routing': 'curved',
          }),
        );
      }
    }
    return [...edges, root, ...nodes];
  }
}

abstract final class CanvasStarters {
  static const all = <CanvasStarter>[
    CanvasStarter(
      id: 'everyday_mind_map',
      name: 'Mind Map',
      mindMap: true,
      description: 'A central question with six connected, editable branches.',
      tags: ['ideas', 'brainstorm', 'thinking', 'mind map'],
      prompts: [
        (
          title: 'Possibilities',
          prompt: 'What could this become? Keep several directions open.',
        ),
        (
          title: 'People & needs',
          prompt: 'Who is involved? What matters to them?',
        ),
        (
          title: 'Evidence',
          prompt: 'What do we know? Place real sources beside this branch.',
        ),
        (title: 'Constraints', prompt: 'What must hold? What could change?'),
        (
          title: 'Connections',
          prompt: 'What does this remind you of? Join related branches.',
        ),
        (
          title: 'Next experiment',
          prompt: 'What is the smallest useful thing to try?',
        ),
      ],
    ),
    CanvasStarter(
      id: 'everyday_ideas',
      name: 'Idea Exploration',
      description: 'Move from open possibilities to a specific experiment.',
      tags: ['ideas', 'creative', 'brainstorm'],
      prompts: [
        (
          title: 'The opportunity',
          prompt: 'Whose problem or wish are we exploring?',
        ),
        (
          title: 'Many possibilities',
          prompt: 'Add sticky notes. Try an opposite or unlikely approach.',
        ),
        (
          title: 'References',
          prompt: 'Place existing notes, images and sources here.',
        ),
        (
          title: 'Promising directions',
          prompt: 'Which ideas deserve a small test, and why?',
        ),
        (
          title: 'Unknowns',
          prompt: 'What assumption could make the idea fail?',
        ),
        (
          title: 'Try next',
          prompt: 'Choose one test, an owner and a review date.',
        ),
      ],
    ),
    CanvasStarter(
      id: 'everyday_reflection',
      name: 'Reflection Board',
      description: 'A visual journal for moments, lessons and what comes next.',
      tags: ['journal', 'reflection', 'personal'],
      prompts: [
        (
          title: 'Moments to keep',
          prompt: 'What happened? Add a photo, note or small memory.',
        ),
        (
          title: 'What gave me energy',
          prompt: 'People, places and work I want more of.',
        ),
        (
          title: 'What felt difficult',
          prompt: 'Describe the situation without judging yourself.',
        ),
        (
          title: 'What I learned',
          prompt: 'What surprised me or changed my thinking?',
        ),
        (
          title: 'Let go / simplify',
          prompt: 'What can become smaller or stop?',
        ),
        (
          title: 'Next small step',
          prompt: 'One realistic action for the next day or week.',
        ),
      ],
    ),
    CanvasStarter(
      id: 'everyday_outdoors',
      name: 'Outdoor Adventure',
      description:
          'Plan a walk, hike or camping trip with route and check-in details.',
      tags: ['outdoor', 'nature', 'hiking', 'camping', 'route'],
      prompts: [
        (title: 'Trip brief', prompt: 'Where, when, with whom and why?'),
        (
          title: 'Route & alternatives',
          prompt: 'Place maps, waypoints and a backup route here.',
        ),
        (
          title: 'Conditions',
          prompt: 'Check current weather, access, daylight and local rules.',
        ),
        (
          title: 'Kit & supplies',
          prompt: 'What does the route and group need? Who brings it?',
        ),
        (
          title: 'Return & check-in',
          prompt: 'Turnaround time, trusted contact and agreed check-in plan.',
        ),
        (
          title: 'After the trip',
          prompt: 'Actual conditions, memories and lessons for next time.',
        ),
      ],
    ),
    CanvasStarter(
      id: 'everyday_nature',
      name: 'Nature Observation',
      mindMap: true,
      description:
          'Connect a habitat or observation to evidence and follow-up questions.',
      tags: ['nature', 'wildlife', 'field', 'garden', 'observation'],
      prompts: [
        (
          title: 'Place & conditions',
          prompt: 'Date, habitat, weather and time spent observing.',
        ),
        (
          title: 'What I saw',
          prompt: 'Shape, size, color, count and behavior before naming it.',
        ),
        (
          title: 'What I heard',
          prompt: 'Describe the sound and context. Add owned recordings.',
        ),
        (
          title: 'Photos & sketches',
          prompt: 'Place evidence here, with a useful caption.',
        ),
        (
          title: 'Identification',
          prompt: 'Possible names, confidence and guide/source consulted.',
        ),
        (
          title: 'Questions to revisit',
          prompt:
              'What should I observe next? Protect sensitive locations when sharing.',
        ),
      ],
    ),
    CanvasStarter(
      id: 'everyday_ai_lab',
      name: 'AI Experiment Board',
      description:
          'Keep prompts, cases, outputs and human verification together.',
      tags: ['AI', 'prompt', 'LLM', 'evaluation', 'experiment'],
      prompts: [
        (
          title: 'Task & boundaries',
          prompt: 'Intended use, permitted data and unacceptable outcomes.',
        ),
        (
          title: 'Prompt versions',
          prompt:
              'Record the prompt, model/version and settings you actually used.',
        ),
        (
          title: 'Test cases',
          prompt: 'Typical, ambiguous and edge cases with expected behavior.',
        ),
        (
          title: 'Outputs & evidence',
          prompt: 'Keep observed results separate from expected results.',
        ),
        (
          title: 'Human verification',
          prompt: 'Check claims, sources and failures against a fixed rubric.',
        ),
        (
          title: 'Decision & next test',
          prompt:
              'What improved? What remains untested? No model runs automatically.',
        ),
      ],
    ),
    CanvasStarter(
      id: 'everyday_trip',
      name: 'Travel Planner',
      description: 'A flexible itinerary with bookings, places and memories.',
      tags: ['travel', 'trip', 'life', 'itinerary'],
      prompts: [
        (
          title: 'Trip priorities',
          prompt: 'Dates, companions, budget and what matters most.',
        ),
        (
          title: 'Places & references',
          prompt: 'Maps, ideas, accommodation and transport sources.',
        ),
        (
          title: 'Itinerary',
          prompt: 'A flexible sequence, with travel time and alternatives.',
        ),
        (
          title: 'Practical details',
          prompt: 'Arrival, access needs and essential offline information.',
        ),
        (
          title: 'Before departure',
          prompt: 'Confirm current requirements, bookings and shared plans.',
        ),
        (
          title: 'Travel journal',
          prompt: 'Moments, photos and recommendations to keep.',
        ),
      ],
    ),
    CanvasStarter(
      id: 'everyday_world',
      name: 'Story World',
      mindMap: true,
      description:
          'Connect a setting to people, rules, places and story opportunities.',
      tags: ['writing', 'worldbuilding', 'game', 'story', 'creative'],
      prompts: [
        (
          title: 'Places',
          prompt: 'Landscape, routes and locations that create choices.',
        ),
        (
          title: 'People',
          prompt: 'Characters and groups: wants, needs and tensions.',
        ),
        (
          title: 'Rules & costs',
          prompt: 'What is possible? What does it cost?',
        ),
        (
          title: 'Everyday life',
          prompt: 'Work, culture, resources and an ordinary day.',
        ),
        (title: 'Conflicts', prompt: 'What happens when these needs collide?'),
        (
          title: 'Scenes & quests',
          prompt: 'Reveal this world through action, play or a scene.',
        ),
      ],
    ),
  ];

  static CanvasStarter? byId(String id) {
    for (final starter in all) {
      if (starter.id == id) return starter;
    }
    return null;
  }

  static List<CanvasStarter> search(String query) {
    final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
    return all.where((s) {
      final text = '${s.name} ${s.description} ${s.tags.join(' ')}'
          .toLowerCase();
      return terms.every(text.contains);
    }).toList();
  }
}
