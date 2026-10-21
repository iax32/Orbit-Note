part of 'note_templates.dart';

/// Ordinary Markdown starters; no service, account or generated answers required.
abstract final class EverydayNoteTemplates {
  static const all = <NoteTemplate>[
    NoteTemplate(
      id: 'ideas_mind_map',
      name: 'Mind Map Outline',
      description:
          'Explore a central question through branches, evidence and connections.',
      icon: Icons.hub_outlined,
      defaultTitle: 'Mind Map',
      categoryOverride: NoteTemplateCategory.ideas,
      customizable: true,
      tags: ['mind map', 'brainstorm', 'outline', 'connections'],
      body: '''# {{title}}

**Explored on:** {{date}}
**Central question:**

## Possibilities
- Direction:
  - Why it might work:
  - Example or reference:
- A very different direction:
  - What would need to be true:

## Constraints
- Must have:
- Can change:

## Connections
Which branches reinforce or contradict each other? Link actual notes or sources.

## Next small experiment
- [ ] Test one branch
- What would make us change direction?

Tip: paste an indented outline into Canvas → Import Diagrams & Content → Outline
to turn your branches into an editable mind map.
''',
    ),
    NoteTemplate(
      id: 'ideas_exploration',
      name: 'Idea Exploration',
      description:
          'Diverge first, then compare ideas with a small, testable next step.',
      icon: Icons.lightbulb_outline,
      defaultTitle: 'Idea Exploration',
      categoryOverride: NoteTemplateCategory.ideas,
      customizable: true,
      tags: ['brainstorm', 'creative', 'experiment'],
      body: '''# {{title}}

**Date:** {{date}}
**Opportunity or frustration:**
**Who experiences it:**

## Generate without judging
1. The straightforward approach:
2. The opposite approach:
3. A combination of two unrelated things:
4. What would we try with half the time or resources?

## Compare
| Idea | Benefit | Biggest unknown | Smallest test | Effort |
| --- | --- | --- | --- | --- |
| | | | | |

## Try next
**Chosen idea and why:**
**Evidence we need:**
- [ ] Run the smallest test
**Review date:**
**Parked ideas worth keeping:**
''',
    ),
    NoteTemplate(
      id: 'ideas_problem',
      name: 'Problem Framing',
      description:
          'Separate symptoms from causes and decide what a useful result means.',
      icon: Icons.search_outlined,
      defaultTitle: 'Problem to Explore',
      categoryOverride: NoteTemplateCategory.ideas,
      customizable: true,
      tags: ['problem', 'research', 'root cause'],
      body: '''# {{title}}

**Date:** {{date}}
## What happened?
Describe a concrete example, who was affected and where it occurred.

## Facts versus assumptions
| Observation / source | Possible explanation | How to check |
| --- | --- | --- |
| | | |

## Reframe the question
- Original question:
- What are we assuming cannot change?
- A narrower question we can answer:

## Define a useful result
**Success looks like:**
**Outside this investigation:**
- [ ] Gather one piece of evidence that could disprove the leading explanation
''',
    ),
    NoteTemplate(
      id: 'journal_daily',
      name: 'Daily Journal',
      description:
          'A light daily record with space for events, reflection and tomorrow.',
      icon: Icons.edit_calendar_outlined,
      defaultTitle: 'Daily Journal',
      categoryOverride: NoteTemplateCategory.journal,
      customizable: true,
      tags: ['journal', 'daily', 'diary'],
      body: '''# {{title}}

**Date:** {{date}}
## Today, in a few words

## What happened

## A moment to keep

## What is on my mind?

## One thing for tomorrow
- [ ]
''',
    ),
    NoteTemplate(
      id: 'journal_weekly',
      name: 'Weekly Reflection',
      description:
          'Review what mattered, what drained your time and what to change.',
      icon: Icons.history_edu_outlined,
      defaultTitle: 'Weekly Reflection',
      categoryOverride: NoteTemplateCategory.journal,
      customizable: true,
      tags: ['journal', 'weekly', 'reflection'],
      body: '''# {{title}}

**Week of:** {{date}}
## What moved forward?
- A result I can point to:
- Something I learned:

## What took more than it gave?
What can I stop, simplify or ask for help with?

## Keep / change / let go
| Keep | Change | Let go |
| --- | --- | --- |
| | | |

## Next week's focus
**One meaningful outcome:**
**A realistic first step:**
**Time I want to protect:**
''',
    ),
    NoteTemplate(
      id: 'journal_gratitude',
      name: 'Small Moments',
      description:
          'Notice people, ordinary details and things you want to remember.',
      icon: Icons.wb_sunny_outlined,
      defaultTitle: 'Small Moments',
      categoryOverride: NoteTemplateCategory.journal,
      customizable: true,
      tags: ['gratitude', 'journal', 'memory'],
      body: '''# {{title}}

**Date:** {{date}}
## Three things I noticed
1.
2.
3.

## Someone who made a difference
What did they do, and what would I like to tell them?

## A detail worth remembering
A sound, place, conversation, photo or small achievement.

## Make room for it again
One simple way to repeat a good part of today.
''',
    ),
    NoteTemplate(
      id: 'outdoor_trail',
      name: 'Hike & Trail Plan',
      description:
          'Plan a route, conditions, equipment and a clear return/check-in plan.',
      icon: Icons.hiking_outlined,
      defaultTitle: 'Trail Plan',
      categoryOverride: NoteTemplateCategory.outdoors,
      customizable: true,
      tags: ['outdoor', 'hiking', 'nature', 'route', 'walk'],
      body: '''# {{title}}

**Planned on:** {{date}}
**Trip date / group:**
**Route / map source:**
**Distance / elevation / expected duration:**

## Route and alternatives
| Segment / waypoint | Time estimate | Navigation note | Alternative / turnaround |
| --- | --- | --- | --- |
| | | | |

## Before leaving
- [ ] Check current local weather, closures and daylight
- [ ] Download maps for offline use
- [ ] Match equipment, food and water to the route and group
- [ ] Share route and expected return with a trusted contact

**Turnaround time / conditions:**
**Check-in contact / agreed action if overdue:**
**Local emergency information:**

## After the trip
Actual route, conditions, highlights and what to change next time.
''',
    ),
    NoteTemplate(
      id: 'outdoor_camping',
      name: 'Camping Weekend',
      description:
          'Keep campsite logistics, shared kit and responsibilities in one plan.',
      icon: Icons.forest_outlined,
      defaultTitle: 'Camping Plan',
      categoryOverride: NoteTemplateCategory.outdoors,
      customizable: true,
      tags: ['camping', 'outdoor', 'nature', 'packing'],
      body: '''# {{title}}

**Planned on:** {{date}}
**Dates / location / booking reference:**
**People / transport:**

## Site and conditions
- Access / arrival window:
- Water / facilities:
- Current local rules, fire restrictions and weather source:
- Backup plan:

## Shared kit
| Item | Person responsible | Packed | Notes |
| --- | --- | --- | --- |
| Shelter / sleeping | | No | |
| Cooking / food / water | | No | |
| Lighting / navigation | | No | |
| First aid / essentials | | No | |

## Meals and activities

## Leaving the site
- [ ] Collect belongings and waste
- [ ] Check the site and follow local leave-no-trace guidance
## What to remember next time
''',
    ),
    NoteTemplate(
      id: 'nature_field_log',
      name: 'Nature Field Log',
      description:
          'Record observations with location, conditions and identification confidence.',
      icon: Icons.eco_outlined,
      defaultTitle: 'Nature Field Log',
      categoryOverride: NoteTemplateCategory.outdoors,
      customizable: true,
      tags: ['nature', 'observation', 'bird', 'wildlife', 'field journal'],
      body: '''# {{title}}

**Date:** {{date}}
**Place / habitat:**
**Time / weather / observation effort:**

## Observations
| Time | What I observed | Count / behavior | Photo / sketch | Identification confidence |
| --- | --- | --- | --- | --- |
| | | | | |

## Details before naming
Shape, size, color, movement, sound and surroundings. Keep uncertain IDs explicit.

## Follow-up
- Identification question:
- Field guide or source consulted:
- [ ] Revisit an uncertain observation

**Sharing note:** omit precise locations for sensitive species or private sites.
''',
    ),
    NoteTemplate(
      id: 'nature_garden',
      name: 'Garden & Growing Log',
      description:
          'Track a bed or container from sowing to observations and next season.',
      icon: Icons.yard_outlined,
      defaultTitle: 'Garden Log',
      categoryOverride: NoteTemplateCategory.outdoors,
      customizable: true,
      tags: ['garden', 'nature', 'plants', 'growing'],
      body: '''# {{title}}

**Started:** {{date}}
**Bed / container / location:**
**Light / soil / watering setup:**

## Planting plan
| Plant / variety | Sown / planted | Spacing / source | Expected milestone |
| --- | --- | --- | --- |
| | | | |

## Observation log
| Date | Growth / conditions | Action taken | Result / photo |
| --- | --- | --- | --- |
| | | | |

## Next visit
- [ ]
## Keep for next season
What grew well here? What would I change, and why?
''',
    ),
    NoteTemplate(
      id: 'nature_sky',
      name: 'Night Sky Session',
      description: 'Plan a viewing session and log what was actually visible.',
      icon: Icons.nightlight_outlined,
      defaultTitle: 'Night Sky Notes',
      categoryOverride: NoteTemplateCategory.outdoors,
      customizable: true,
      tags: ['astronomy', 'stargazing', 'nature', 'observing'],
      body: '''# {{title}}

**Date:** {{date}}
**Site / local time zone:**
**Weather / moon / light conditions:**
**Equipment / chart source:**

## Targets
| Object | Direction / viewing window | Chart / reference | Observed? |
| --- | --- | --- | --- |
| | | | |

## Session log
Time, magnification or camera settings, visible detail and sketches.

## Next time
What would improve the view or make setup easier?
''',
    ),
    NoteTemplate(
      id: 'life_travel',
      name: 'Trip & Travel Journal',
      description:
          'Combine a flexible itinerary, practical details and memories.',
      icon: Icons.luggage_outlined,
      defaultTitle: 'Travel Notebook',
      categoryOverride: NoteTemplateCategory.life,
      customizable: true,
      tags: ['travel', 'trip', 'itinerary', 'journal'],
      body: '''# {{title}}

**Planned on:** {{date}}
**Destination / dates / companions:**
**Budget / priorities:**

## Before departure
- [ ] Check current entry, booking and transport requirements
- [ ] Keep essential references available offline
- [ ] Share relevant itinerary details

## Flexible itinerary
| Day | Base / transport | Main plan | Alternative | Booking / source |
| --- | --- | --- | --- | --- |
| | | | | |

## Practical details
Accommodation, arrival instructions, local contacts and accessibility needs.
Avoid storing passwords or full payment-card details here.

## Moments to keep
Photos, places, conversations and things I would recommend to a friend.
''',
    ),
    NoteTemplate(
      id: 'life_home_project',
      name: 'Home Project',
      description:
          'Plan a repair, room refresh or personal build with a realistic budget.',
      icon: Icons.home_repair_service_outlined,
      defaultTitle: 'Home Project',
      categoryOverride: NoteTemplateCategory.life,
      customizable: true,
      tags: ['home', 'DIY', 'planning', 'budget'],
      body: '''# {{title}}

**Started:** {{date}}
**Desired result / measurements:**
**Budget / time available:**

## Plan before buying
| Step | Materials / tools | Estimate | Who / when |
| --- | --- | --- | --- |
| | | | |

## Questions to settle
Measurements, permissions, specialist help and anything that could change scope.

## Progress
- [ ] Confirm the plan and measurements
- [ ] Gather what is needed
- [ ] Complete and check the result

## Actual cost / lessons
Keep receipts or sources as attachments; record what to do differently.
''',
    ),
    NoteTemplate(
      id: 'life_meal_plan',
      name: 'Meals & Grocery Plan',
      description:
          'Plan meals around what is already available and a grouped shopping list.',
      icon: Icons.restaurant_outlined,
      defaultTitle: 'Meal Plan',
      categoryOverride: NoteTemplateCategory.life,
      customizable: true,
      tags: ['meals', 'food', 'groceries', 'household'],
      body: '''# {{title}}

**Week of:** {{date}}
**People / preferences / available time:**
## Use first
What is already in the kitchen?

## Meals
| Day | Meal / recipe link | Prep needed | Leftovers plan |
| --- | --- | --- | --- |
| | | | |

## Shopping
### Produce
- [ ]
### Pantry / chilled
- [ ]
### Other
- [ ]

## Next week
What was easy, what was wasted and what should we repeat?
''',
    ),
    NoteTemplate(
      id: 'life_habit',
      name: 'Habit Experiment',
      description:
          'Try one small routine and evaluate it without turning misses into failures.',
      icon: Icons.repeat_outlined,
      defaultTitle: 'Habit Experiment',
      categoryOverride: NoteTemplateCategory.life,
      customizable: true,
      tags: ['habit', 'routine', 'personal', 'experiment'],
      body: '''# {{title}}

**Started:** {{date}}
**Routine I want to try:**
**Why it matters to me:**
**Smallest version / trigger:**
**Review date:**

## Observe
| Date | Tried it? | What helped / got in the way | Adjustment |
| --- | --- | --- | --- |
| | | | |

## Review the experiment
- Did this routine help with the original reason?
- What should become easier or smaller?
- Continue, adapt or stop?
''',
    ),
    NoteTemplate(
      id: 'life_practice',
      name: 'Hobby & Practice Session',
      description:
          'A focused record for music, art, craft, language or another skill.',
      icon: Icons.palette_outlined,
      defaultTitle: 'Practice Session',
      categoryOverride: NoteTemplateCategory.life,
      customizable: true,
      tags: ['hobby', 'practice', 'music', 'art', 'language'],
      body: '''# {{title}}

**Date / duration:** {{date}}
**Skill / material / reference:**
**One thing to practice:**

## Session
| Exercise / attempt | What happened | Feedback / evidence |
| --- | --- | --- |
| | | |

## Notice the change
What became easier? Where did I get stuck?

## Next session
**Start here:**
**Materials to have ready:**
''',
    ),
    NoteTemplate(
      id: 'study_sprint',
      name: 'Learning Sprint',
      description:
          'Set a learning question, practice actively and check understanding.',
      icon: Icons.school_outlined,
      defaultTitle: 'Learning Sprint',
      categoryOverride: NoteTemplateCategory.study,
      customizable: true,
      tags: ['learning', 'study', 'course', 'self study'],
      body: '''# {{title}}

**Started:** {{date}}
**Course / topic / source:**
**By the end I want to be able to:**
**Time available / review date:**

## Plan
| Question / skill | Source / exercise | Evidence I understand it |
| --- | --- | --- |
| | | |

## Explain without looking
Write the idea in your own words, then compare against the source.

## Gaps to revisit
- Question:
- Example or counterexample:

## Finish
- [ ] Try a fresh problem without the answer visible
- [ ] Link follow-up notes or flashcards
''',
    ),
    NoteTemplate(
      id: 'study_assignment',
      name: 'Assignment Planner',
      description:
          'Break a university or school assignment into evidence and deliverables.',
      icon: Icons.assignment_outlined,
      defaultTitle: 'Assignment Plan',
      categoryOverride: NoteTemplateCategory.study,
      customizable: true,
      tags: ['university', 'assignment', 'course', 'study'],
      body: '''# {{title}}

**Planned on:** {{date}}
**Course / module / instructor:**
**Deadline / submission location:**
**Required format / word limit / assessment criteria:**

## What the prompt actually asks
Restate the deliverable and any required evidence in your own words.

## Work backwards
| Milestone | Target date | Done when | Linked work |
| --- | --- | --- | --- |
| Research / practice | | | |
| Draft / implementation | | | |
| Review / submission | | | |

## Questions / sources

## Before submitting
- [ ] Check the rubric and permitted tools
- [ ] Verify citations, files and final format
- [ ] Submit and keep the confirmation
''',
    ),
    NoteTemplate(
      id: 'work_kickoff',
      name: 'Project Kickoff',
      description:
          'Align purpose, boundaries, responsibilities and the first milestone.',
      icon: Icons.flag_outlined,
      defaultTitle: 'Project Kickoff',
      categoryOverride: NoteTemplateCategory.work,
      customizable: true,
      tags: ['project', 'brief', 'planning', 'team'],
      body: '''# {{title}}

**Date:** {{date}}
**Owner / collaborators:**
**Problem and intended audience:**
**A successful result looks like:**

## Scope
- Included:
- Explicitly outside this project:
- Constraints:

## First milestones
| Outcome | Owner | Target | Evidence of completion |
| --- | --- | --- | --- |
| | | | |

## Risks / assumptions / open decisions
What could change the plan? Link evidence rather than treating guesses as facts.

## Next conversation
- [ ] Agree on the first deliverable and review date
''',
    ),
    NoteTemplate(
      id: 'work_retrospective',
      name: 'Project Retrospective',
      description: 'Turn a finished cycle into a few specific improvements.',
      icon: Icons.rate_review_outlined,
      defaultTitle: 'Retrospective',
      categoryOverride: NoteTemplateCategory.work,
      customizable: true,
      tags: ['retrospective', 'review', 'team', 'solo'],
      body: '''# {{title}}

**Date / cycle:** {{date}}
**Intended outcome / actual result:**

## Evidence before explanations
What actually happened? Link examples, metrics or observations.

## Keep / change / try
| Observation | Impact | Proposed change | Owner / review date |
| --- | --- | --- | --- |
| | | | |

## Choose a small improvement
**One change for the next cycle:**
**How we will know it helped:**
**What we are deliberately not changing yet:**
''',
    ),
    NoteTemplate(
      id: 'ai_prompt_lab',
      name: 'AI Prompt Lab',
      description:
          'Version prompts, keep test cases and record verified results.',
      icon: Icons.science_outlined,
      defaultTitle: 'Prompt Experiment',
      categoryOverride: NoteTemplateCategory.ai,
      customizable: true,
      tags: ['AI', 'prompt', 'LLM', 'experiment', 'evaluation'],
      body: '''# {{title}}

**Date:** {{date}}
**Task / intended user:**
**Model / version / settings (if used):**
**Data permitted in this experiment:**

## Prompt version
```text
Goal:
Relevant context:
Constraints:
Expected output:
```

## Test cases
| Input / case | Expected behavior | Actual output / source | Pass? | Failure mode |
| --- | --- | --- | --- | --- |
| Typical | | | | |
| Ambiguous / adversarial | | | | |

## Change one thing
**Prompt change / hypothesis:**
**Measured difference:**
**Claims requiring human verification:**

This is an offline experiment record. Inserting this template does not run a model
or send any data to an AI service.
''',
    ),
    NoteTemplate(
      id: 'ai_evaluation',
      name: 'AI Evaluation Plan',
      description:
          'Compare systems against a repeatable rubric and inspect failures.',
      icon: Icons.fact_check_outlined,
      defaultTitle: 'AI Evaluation',
      categoryOverride: NoteTemplateCategory.ai,
      customizable: true,
      tags: ['AI', 'eval', 'benchmark', 'quality', 'model'],
      body: '''# {{title}}

**Date:** {{date}}
**Use case / systems compared / versions:**
**Decision this evaluation should support:**

## Rubric before results
| Criterion | How to measure | Acceptable threshold | Weight / reason |
| --- | --- | --- | --- |
| Correctness | | | |
| Unsupported claims | | | |
| Latency / cost | | | |

## Dataset and method
Source, permitted use, representative cases, held-out cases and known gaps.

## Results
| Case | System / configuration | Score | Evidence | Reviewer |
| --- | --- | --- | --- | --- |
| | | | | |

## Failure analysis and decision
What failed, for whom, and what remains untested? Record limits with the conclusion.
''',
    ),
    NoteTemplate(
      id: 'ai_research',
      name: 'AI Research Reading',
      description:
          'Understand a paper or technique through claims, evidence and reproduction.',
      icon: Icons.manage_search_outlined,
      defaultTitle: 'AI Research Notes',
      categoryOverride: NoteTemplateCategory.ai,
      customizable: true,
      tags: ['AI', 'paper', 'research', 'machine learning'],
      body: '''# {{title}}

**Read on:** {{date}}
**Paper / authors / date / source:**
**Question it addresses:**

## Method in my own words
Inputs, assumptions, core technique and output.

## Evidence
| Claim | Experiment / figure | Baseline | Limitation / open question |
| --- | --- | --- | --- |
| | | | |

## Reproduction plan
**Code / data / license:**
**Compute and dependencies needed:**
**Smallest useful reproduction:**
- [ ] Check one claim against the original evidence

## Relevance to my work
What would this change, and what would I need to verify first?
''',
    ),
    NoteTemplate(
      id: 'ai_dataset',
      name: 'Dataset Card',
      description:
          'Document provenance, permitted use, coverage and data quality.',
      icon: Icons.dataset_outlined,
      defaultTitle: 'Dataset Card',
      categoryOverride: NoteTemplateCategory.ai,
      customizable: true,
      tags: ['AI', 'dataset', 'data', 'provenance'],
      body: '''# {{title}}

**Recorded on:** {{date}}
**Dataset / version / owner:**
**Source / license / permitted use:**
**Intended use / excluded uses:**

## Composition
| Field | Meaning / units | Missing values | Validation |
| --- | --- | --- | --- |
| | | | |

## Collection and preparation
Sampling, transformations, consent or permissions, splits and leakage checks.

## Coverage and limitations
Who or what is missing? Where should conclusions not be generalized?

## Quality checks
- [ ] Check duplicates, labels and missing data
- [ ] Inspect sensitive information and access needs
- [ ] Record version and reproducible preparation steps

## Change log
| Date | Change | Reason / impact |
| --- | --- | --- |
| | | |
''',
    ),
    NoteTemplate(
      id: 'life_community',
      name: 'Community Event',
      description:
          'Plan a meetup, club session or volunteer event with clear responsibilities.',
      icon: Icons.groups_outlined,
      defaultTitle: 'Community Event',
      categoryOverride: NoteTemplateCategory.life,
      customizable: true,
      tags: ['community', 'event', 'volunteer', 'club'],
      body: '''# {{title}}

**Planned on:** {{date}}
**Purpose / audience / capacity:**
**Date / venue / contact:**
**Budget / accessibility / participation needs:**

## Run of show
| Time | Activity | Responsible person | Materials / fallback |
| --- | --- | --- | --- |
| | | | |

## Before the event
- [ ] Confirm venue and responsibilities
- [ ] Share accurate practical information
- [ ] Check access, supplies and backup arrangements

## After
Attendance, feedback, outstanding costs and what to keep for the next event.
''',
    ),
    NoteTemplate(
      id: 'writing_worldbuilding',
      name: 'Worldbuilding Fieldbook',
      description:
          'Connect places, culture and constraints to the stories they create.',
      icon: Icons.public_outlined,
      defaultTitle: 'Worldbuilding Fieldbook',
      categoryOverride: NoteTemplateCategory.writing,
      customizable: true,
      tags: ['worldbuilding', 'fiction', 'game', 'story', 'setting'],
      body: '''# {{title}}

**Started:** {{date}}
**Setting / scope / tone:**
**One rule that makes this world distinctive:**

## Place and everyday life
Landscape, resources, work, travel and what an ordinary day feels like.

## People and power
| Group / character | Wants | Depends on | Tension / story opportunity |
| --- | --- | --- | --- |
| | | | |

## Rules and consequences
What is possible here? What is costly? What happens when someone breaks a rule?

## Story seeds
- A conflict caused by this setting:
- A place to explore or illustrate:
- A detail to reveal through play or a scene:

## Consistency questions
Keep unresolved lore explicit; link characters, maps and decisions as they exist.
''',
    ),
  ];
}
