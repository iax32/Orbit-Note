import 'package:flutter/material.dart';

/// A reusable starter template for Markdown documents in Orbit Note.
class NoteTemplate {
  const NoteTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.defaultTitle,
    required this.body,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String defaultTitle;
  final String body;
  final List<String> tags;

  String get content => body;
}

/// Catalog of built-in Markdown note templates adhering to Orbit Note standards.
class NoteTemplates {
  const NoteTemplates._();

  static const cornell = NoteTemplate(
    id: 'cornell',
    name: 'Cornell Notes',
    description:
        'Dual-column study structure with cue keywords, lecture notes, and summary.',
    icon: Icons.school_outlined,
    defaultTitle: 'Cornell Notes: Subject',
    tags: ['study', 'cornell'],
    body: '''# Cornell Notes: [Subject / Topic]

**Subject:** [Course / Field]  
**Date:** [Date]  
**Source / Lecturer:** [[Source Document or Reference]]

---

## Cue Column / Keywords
*Key concepts, core questions, recall prompts, and memory triggers:*
- Key Concept 1
- Prompt / Question: What defines this mechanism?
- Essential vocabulary & formulas

## Notes Area
*Main lecture content, derivations, definitions, and detailed explanations:*

### 1. Introduction & Overview
- Detailed notes from reading or lecture session.
- Sub-points and structural diagrams.

### 2. Theoretical Principles
- Principle A: Context and significance.
- Mathematical / conceptual formulation:
  \$\$ f(x) = \\int_0^x g(t) \\, dt \$\$

### 3. Practical Applications & Examples
- Example scenario illustrating the principles above.
- Key nuances or edge cases to remember.

---

## Summary
*Brief 2–3 sentence synthesis capturing the essence in your own words:*
> Summarize the core takeaway here to solidify understanding and accelerate exam revision.
''',
  );

  static const meeting = NoteTemplate(
    id: 'meeting',
    name: 'Meeting & Action Items',
    description:
        'Structured meeting record with attendees, agenda, decisions, and task checklists.',
    icon: Icons.groups_outlined,
    defaultTitle: 'Meeting: Topic',
    tags: ['meeting', 'work'],
    body: '''# Meeting: [Topic]

**Date:** [Date] | **Time:** [Time]  
**Attendees:** @participant1, @participant2  
**Goal / Purpose:** [Primary objective of this meeting]

---

## Agenda
1. Review previous milestones & open items
2. Core discussion topic
3. Technical / tactical decisions
4. Action items & ownership assignments

## Discussion & Notes
- Key insight or problem context discussed.
- Discussion points and options evaluated.

## Decisions Made
- [x] **Decision 1:** Selected approach and rationale.
- [x] **Decision 2:** Timeline and scope agreement.

## Action Items
- [ ] Task 1 (@owner — due date)
- [ ] Task 2 (@owner — due date)
- [ ] Follow up on open dependency (@owner)
''',
  );

  static const weeklyReview = NoteTemplate(
    id: 'weekly_review',
    name: 'Weekly Review & Reflection',
    description:
        'End-of-week retrospective covering accomplishments, challenges, and upcoming priorities.',
    icon: Icons.calendar_view_week_outlined,
    defaultTitle: 'Weekly Review — Week [N]',
    tags: ['review', 'planning'],
    body: '''# Weekly Review — [Week / Date Range]

> "Reflection turns experience into insight."

---

## Highlights & Accomplishments
- Major milestone reached or feature delivered
- Significant personal or academic progress
- Key win or positive breakthrough

## Challenges & Friction Points
- What caused unexpected delays or cognitive fatigue?
- What process or distraction needs adjustment?

## Key Metrics & Progress
- Focus sessions completed: [N]
- Documents & research notes synthesized: [N]
- Code commits / project tasks closed: [N]

## Priorities for Next Week
1. **Primary Focus:** [Key deliverable]
2. **Secondary Goal:** [Supporting task]
3. **Exploratory / Learning:** [Topic to research]
''',
  );

  static const literature = NoteTemplate(
    id: 'literature',
    name: 'Literature & Research Note',
    description:
        'Academic reading note synthesizing citations, core thesis, arguments, and critique.',
    icon: Icons.menu_book_outlined,
    defaultTitle: 'Lit Note: Author — Title',
    tags: ['research', 'literature'],
    body: '''# Literature Note: [Work Title]

**Author(s):** [Author Name(s)]  
**Year / Publication:** [Year], *[Journal / Publisher]*  
**Source / DOI:** [[Link or File Reference]]  
**Tags:** #research #paper

---

## Core Thesis
> State the fundamental argument or empirical discovery of the paper in one clear sentence.

## Key Arguments & Methodology
1. **Hypothesis / Question:** What specific gap does this research address?
2. **Methodology:** Theoretical framework, dataset, or experiment design.
3. **Empirical Findings:** The primary results and statistical significance.

## Important Quotes & References
> "Direct quote from the text that captures a seminal insight or definition." (p. 42)

## Personal Critique & Synthesis
- Strengths of the author's argument.
- Limitations, unaccounted variables, or open questions.
- How does this connect to my current research or project?

## Related Work & Backlinks
- Connects to: [[Related Note 1]]
- Contrasts with: [[Alternative Theory]]
''',
  );

  static const dailyStandup = NoteTemplate(
    id: 'daily_standup',
    name: 'Daily Standup & Focus Log',
    description:
        'Daily log for deep work sessions, tracking progress, blockers, and intentional focus.',
    icon: Icons.today_outlined,
    defaultTitle: 'Daily Log — [Date]',
    tags: ['daily', 'journal'],
    body: '''# Daily Log — [Date]

**Morning Focus:** [Top priority for today]  
**Energy Level:** 🟢 High / 🟡 Medium / 🔴 Low

---

## Yesterday's Achievements
- [x] Closed task or writing milestone
- [x] Reviewed research papers

## Today's Core Priorities (Top 3)
- [ ] 1. Deep work on primary objective
- [ ] 2. Core implementation or study block
- [ ] 3. Admin / coordination tasks

## Blockers & Open Dependencies
- None currently / [Describe any blocker]

## Quick Notes & Fleeting Thoughts
- Captured thought or insight during the day.
''',
  );

  static const projectRfc = NoteTemplate(
    id: 'project_rfc',
    name: 'Project Specification / RFC',
    description:
        'Request for Comments / technical specification for features, architecture, and design.',
    icon: Icons.design_services_outlined,
    defaultTitle: 'RFC: Feature / Architecture Name',
    tags: ['project', 'spec'],
    body: '''# RFC: [Feature / System Name]

**Author:** [Your Name]  
**Date:** [Date]  
**Status:** In Review (Draft / Approved / Implemented)

---

## 1. Summary & Motivation
Provide a high-level overview explaining what problem this proposal solves and why it is essential.

## 2. Goals & Non-Goals
### Goals
- Goal 1: Explicit target outcome
- Goal 2: Performance or usability target

### Non-Goals
- Explicitly out of scope for this version

## 3. Proposed Architecture & Design
Detailed technical or architectural blueprint.

```dart
// Example interface or data flow
abstract class FeatureEngine {
  Future<void> execute();
}
```

## 4. Trade-offs & Alternatives Considered
- **Alternative A:** Why this was not chosen.
- **Alternative B:** Pros and cons evaluated.

## 5. Security, Privacy & Local-First Invariants
- Works 100% offline without mandatory account.
- Preserves open Markdown and document data ownership.

## 6. Implementation Milestones
- [ ] Phase 1: Core data structures & unit tests
- [ ] Phase 2: User interface & command palette integration
- [ ] Phase 3: Validation, formatting, and performance audit
''',
  );

  static const blank = NoteTemplate(
    id: 'blank',
    name: 'Blank Markdown Note',
    description: 'Clean document ready for freeform writing and thought.',
    icon: Icons.note_alt_outlined,
    defaultTitle: 'Untitled Note',
    tags: [],
    body: '',
  );

  static const softwareDesign = NoteTemplate(
    id: 'software_design',
    name: 'Software Design Brief',
    description:
        'A focused brief for a feature, service, or technical change with decisions and acceptance checks.',
    icon: Icons.architecture_outlined,
    defaultTitle: 'Design Brief: Feature',
    tags: ['software', 'design', 'engineering'],
    body: '''# Design Brief: [Feature / System]

**Owner:** [Name]  
**Status:** Draft / In review / Accepted  
**Target release:** [Version or date]

## Problem
What user or system problem are we solving?

## Desired outcome
- [ ] Observable outcome 1
- [ ] Observable outcome 2

## Constraints & non-goals
- Constraint: 
- Non-goal: 

## Proposed design
Describe the flow, data, boundaries, and failure states.

## Alternatives considered
| Option | Benefit | Cost / risk | Decision |
|---|---|---|---|
| A |  |  |  |

## Acceptance checks
- [ ] Happy path works offline
- [ ] Existing documents remain readable
- [ ] Failure state is recoverable

## Open questions
- 
''',
  );

  static const researchLog = NoteTemplate(
    id: 'research_log',
    name: 'Research Log',
    description:
        'Repeatable investigation record for sources, observations, evidence, and the next experiment.',
    icon: Icons.science_outlined,
    defaultTitle: 'Research Log: Topic',
    tags: ['research', 'investigation'],
    body: '''# Research Log: [Topic]

**Date:** [Date]  
**Question:** [What are you trying to learn?]  
**Confidence:** Low / Medium / High

## Working hypothesis
I currently think that...

## Sources & provenance
- [[Source]] — [what it contributes]

## Observations
- Observation: 
- Evidence location: 

## Interpretation
What do the observations support, contradict, or leave uncertain?

## Next experiment
- [ ] Action: 
- Expected result: 
- Stop condition: 

## Changes since last entry
- 
''',
  );

  static const bookNotes = NoteTemplate(
    id: 'book_notes',
    name: 'Book & Course Reading',
    description:
        'A readable reading record for chapters, ideas, quotes, and practical takeaways.',
    icon: Icons.auto_stories_outlined,
    defaultTitle: 'Reading Notes: Title',
    tags: ['reading', 'study'],
    body: '''# Reading Notes: [Title]

**Author / instructor:** [Name]  
**Chapter / lesson:** [Section]  
**Read on:** [Date]

## The point in one sentence

## Key ideas
1. **Idea:** [Explain it in your own words]
   - Example:
   - Why it matters:

## Questions & connections
- Question: 
- Connects to: [[Related Note]]

## Quotes to revisit
> “Quote” (p. [number])

## Practice / application
- [ ] Apply this idea to:

## Summary
''',
  );

  static const List<NoteTemplate> all = [
    cornell,
    meeting,
    weeklyReview,
    literature,
    dailyStandup,
    projectRfc,
    softwareDesign,
    researchLog,
    bookNotes,
    creativeBrief,
    storyboard,
    playtestPlan,
    htmlCode,
    cssCode,
    cppCode,
    javascriptCode,
    ...storyTemplates,
    blank,
  ];

  static const storyTemplates = <NoteTemplate>[
    NoteTemplate(
      id: 'story_outline',
      name: 'Story Outline',
      description:
          'Build a premise, stakes and cause-and-effect chapter outline.',
      icon: Icons.auto_stories_outlined,
      defaultTitle: 'Story Outline',
      tags: ['writing', 'story', 'narrative'],
      body: '''# Story Outline

**Working title:** 
**Genre / audience:** 
**Length / format:** 
**Premise in one sentence:** 
**Theme as a question:** 

## Protagonist and conflict
- Want:
- Need:
- Opposition:
- Stakes if they fail:

## Story turns
| Turn | Event | Choice | Consequence |
| --- | --- | --- | --- |
| Opening | | | |
| Inciting incident | | | |
| Midpoint | | | |
| Crisis | | | |
| Climax | | | |
| Resolution | | | |

## Chapters and scenes
| Chapter | Viewpoint | Goal | Conflict | Change | Linked scene |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

## Revision questions
- [ ] Every scene changes something
- [ ] Consequences drive the next scene
- [ ] The ending answers the central conflict
''',
    ),
    NoteTemplate(
      id: 'character_arc',
      name: 'Character Arc',
      description:
          'Connect a character’s beliefs, relationships and turning points.',
      icon: Icons.person_outline,
      defaultTitle: 'Character Arc',
      tags: ['writing', 'character', 'game', 'narrative'],
      body: '''# Character Arc

**Name / role:** 
**Linked character profile:** 
**Voice in three words:** 

## Inner conflict
- Public goal:
- Private need:
- Belief that holds them back:
- Origin of that belief:
- Contradiction the audience can see:
- What they refuse to lose:

## Arc through action
| Moment / linked scene | Pressure | Choice | Cost | Belief afterward |
| --- | --- | --- | --- | --- |
| Introduction | | | | |
| First test | | | | |
| Breaking point | | | | |
| Final choice | | | | |

## Relationships
| Character | Shared history | Tension | How it changes |
| --- | --- | --- | --- |
| | | | |

## Game-specific expression
- Behaviour the player can observe:
- Choices that affect this arc:
- Dialogue or quest flags:
- Alternate outcomes:
''',
    ),
    NoteTemplate(
      id: 'world_bible',
      name: 'Worldbuilding Bible',
      description:
          'Keep world rules, locations, factions and continuity consistent.',
      icon: Icons.public_outlined,
      defaultTitle: 'Worldbuilding Bible',
      tags: ['writing', 'worldbuilding', 'game', 'lore'],
      body: '''# Worldbuilding Bible

**Project:** 
**Setting / period:** 
**Tone and visual references:** 

## Rules and limits
| Rule | Cost / limitation | Story consequence | Exceptions |
| --- | --- | --- | --- |
| | | | |

## Locations
| Location / linked note | Purpose | Inhabitants | Conflict | Asset / map |
| --- | --- | --- | --- | --- |
| | | | | |

## Factions
| Faction | Goal | Resources | Rival | Player relationship |
| --- | --- | --- | --- | --- |
| | | | | |

## Timeline and continuity
| Date / order | Event | Who knows | Source |
| --- | --- | --- | --- |
| | | | |

## Language and culture
- Customs and taboos:
- Naming conventions:
- Everyday life:

## Unresolved questions
- [ ] Separate established facts from proposed lore
- [ ] Check contradictions against linked scenes
''',
    ),
    NoteTemplate(
      id: 'dialogue_scene',
      name: 'Dialogue & Scene Script',
      description:
          'Write a scene with subtext, delivery notes and production references.',
      icon: Icons.forum_outlined,
      defaultTitle: 'Dialogue Scene',
      tags: ['writing', 'dialogue', 'game', 'script'],
      body: '''# Dialogue Scene

**Scene ID:** 
**Location / time:** 
**Characters:** 
**Entry condition:** 
**Scene goal / change:** 
**Exit condition:** 

## Beat sheet
| Beat | Action | Intention | Subtext | Player input |
| --- | --- | --- | --- | --- |
| | | | | |

## Script
| Line ID | Speaker | Dialogue | Direction / emotion | Audio / localization |
| --- | --- | --- | --- | --- |
| | | | | |

## Choices and interruptions
| Trigger / choice | Response | State change | Next scene |
| --- | --- | --- | --- |
| | | | |

## Production evidence
- Linked storyboard / level:
- Linked character and reference assets:
- [ ] Read aloud for voice and pacing
- [ ] Check subtitles and accessibility
- [ ] Verify interrupts and repeat visits
''',
    ),
    NoteTemplate(
      id: 'branching_quest',
      name: 'Branching Quest & Choices',
      description:
          'Track conditions, flags, consequences and alternate quest paths.',
      icon: Icons.account_tree_outlined,
      defaultTitle: 'Branching Quest',
      tags: ['game', 'quest', 'writing', 'narrative'],
      body: '''# Branching Quest

**Quest ID / title:** 
**Player motivation:** 
**Linked mechanic / level:** 
**Prerequisites:** 

## State and flags
| Flag | Type / default | Set by | Used by | Reset rule |
| --- | --- | --- | --- | --- |
| | | | | |

## Branch map
| Node ID | Entry condition | Scene / objective | Player choice | Next node | State / reward |
| --- | --- | --- | --- | --- | --- |
| Start | | | | | |

## Outcomes
| Ending | Required choices | Immediate consequence | Later consequence |
| --- | --- | --- | --- |
| | | | |

## Failure and recovery
- Abandon / retry behaviour:
- Save/load mid-quest:
- Required NPC or item unavailable:
- Repeat completion / reward protection:

## Path coverage
- [ ] Every branch has a reachable ending
- [ ] Conditions and defaults are documented
- [ ] Save/load preserves active state
- [ ] Alternate outcomes have linked playtest evidence
''',
    ),
    NoteTemplate(
      id: 'game_narrative',
      name: 'Game Narrative Design',
      description:
          'Connect story pillars to player agency, systems and production scope.',
      icon: Icons.sports_esports_outlined,
      defaultTitle: 'Game Narrative Design',
      tags: ['game', 'writing', 'story', 'narrative'],
      body: '''# Game Narrative Design

**Project / genre:** 
**Player role:** 
**Target session length:** 
**Narrative promise:** 
**Linked GDD / story outline:** 

## Pillars and player agency
| Pillar | Player action | Narrative response | Linked mechanic |
| --- | --- | --- | --- |
| | | | |

## Delivery channels
| Channel | Purpose | When / where | Skip / replay | Scope / budget |
| --- | --- | --- | --- | --- |
| Dialogue | | | | |
| Environment | | | | |
| Quests | | | | |
| Cutscenes | | | | |

## Campaign structure
| Chapter / level | Dramatic question | Gameplay change | Character turn | Exit state |
| --- | --- | --- | --- | --- |
| | | | | |

## Production dependencies
- Character profiles and arcs:
- World rules and continuity:
- Dialogue / localization / audio:
- Models, environments and reference boards:

## Narrative playtest
- [ ] Player understands their immediate goal
- [ ] Choices have readable consequences
- [ ] Skipping dialogue does not block progress
- [ ] Story state survives save/load
- [ ] Record tested build and unresolved findings
''',
    ),
  ];

  static const creativeBrief = NoteTemplate(
    id: 'creative_brief',
    name: 'Creative Project Brief',
    description:
        'Define the audience, outcome, constraints and deliverables before planning production.',
    icon: Icons.design_services_outlined,
    defaultTitle: 'Creative Project Brief',
    tags: ['creative', 'planning', 'project'],
    body: '''# Creative Project Brief

## Outcome
What should this project change for its audience?

## Audience & experience
Who is this for, and how should it feel?

## Constraints
Budget, time, platform, accessibility, and what is out of scope.

## Deliverables & acceptance
| Deliverable | Owner | Due | Acceptance check |
| --- | --- | --- | --- |
| | | | |

## Direction & references
Link a moodboard, notes, or reference material here.

## Explore → decide → produce
- [ ] Gather reference material
- [ ] Explore two directions
- [ ] Record the chosen direction and why
- [ ] Make the smallest useful prototype
- [ ] Review against the acceptance checks

## Decisions & open questions
| Question | Decision / evidence | Next action |
| --- | --- | --- |
| | | |
''',
  );

  static const storyboard = NoteTemplate(
    id: 'storyboard',
    name: 'Storyboard & Shot Plan',
    description:
        'Plan a sequence, assets and transitions for video, narrative, or game scenes.',
    icon: Icons.movie_creation_outlined,
    defaultTitle: 'Storyboard',
    tags: ['creative', 'narrative'],
    body: '''# Storyboard

## Intent
Audience, mood, and the change from beginning to end.

| Beat / shot | Action | Camera / composition | Sound | Assets / references |
| --- | --- | --- | --- | --- |
| Opening | | | | |
| Turning point | | | | |
| Resolution | | | | |

## Production checklist
- [ ] Check pacing with a rough animatic
- [ ] Confirm asset availability
- [ ] Review readability and accessibility

## Review notes
Observation → proposed change → decision.
''',
  );

  static const playtestPlan = NoteTemplate(
    id: 'prototype_review',
    name: 'Prototype & Playtest Plan',
    description:
        'Test a specific hypothesis and turn observations into linked decisions.',
    icon: Icons.sports_esports_outlined,
    defaultTitle: 'Prototype Review',
    tags: ['game', 'creative', 'playtest'],
    body: '''# Prototype Review

## Hypothesis
What do we expect the player or audience to do?

## Test setup
Build/version, platform, participant profile, duration, and instructions.

## Success criteria
Observable behavior and a threshold decided before the test.

| Time / scene | Observation | Evidence / source | Severity | Linked action |
| --- | --- | --- | --- | --- |
| | | | | |

## Decisions
- Keep:
- Change:
- Investigate:

## Next test
- [ ] Create the smallest change that tests the next question
''',
  );

  static const htmlCode = NoteTemplate(
    id: 'code_html',
    name: 'HTML Source',
    description:
        'Editable HTML with syntax highlighting and an expanded code workspace.',
    icon: Icons.code,
    defaultTitle: 'HTML Source',
    tags: ['code', 'html', 'game'],
    body:
        '```html\n<!doctype html>\n<html lang="en">\n  <head>\n    <meta charset="utf-8">\n    <title>Prototype</title>\n  </head>\n  <body>\n    <main></main>\n  </body>\n</html>\n```\n',
  );
  static const cssCode = NoteTemplate(
    id: 'code_css',
    name: 'CSS Source',
    description: 'Stylesheet notes with an expanded editor.',
    icon: Icons.code,
    defaultTitle: 'CSS Source',
    tags: ['code', 'css'],
    body:
        '```css\n:root {\n  color-scheme: light dark;\n}\n\nbody {\n  margin: 0;\n  font-family: system-ui, sans-serif;\n}\n```\n',
  );
  static const cppCode = NoteTemplate(
    id: 'code_cpp',
    name: 'C++ Source',
    description: 'Keep and edit C++ prototypes alongside design notes.',
    icon: Icons.code,
    defaultTitle: 'C++ Source',
    tags: ['code', 'cpp', 'game'],
    body:
        '```cpp\n#include <iostream>\n\nint main() {\n  std::cout << "Prototype\\n";\n  return 0;\n}\n```\n',
  );
  static const javascriptCode = NoteTemplate(
    id: 'code_javascript',
    name: 'JavaScript Source',
    description: 'Editable JavaScript prototypes and scripts.',
    icon: Icons.code,
    defaultTitle: 'JavaScript Source',
    tags: ['code', 'javascript', 'game'],
    body:
        '```javascript\nfunction update(deltaTime) {\n  // Advance the prototype by deltaTime seconds.\n}\n```\n',
  );

  static NoteTemplate? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static List<NoteTemplate> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((t) {
      if (t.name.toLowerCase().contains(q)) return true;
      if (t.description.toLowerCase().contains(q)) return true;
      if (t.tags.any((tag) => tag.toLowerCase().contains(q))) return true;
      if (t.body.toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }
}
