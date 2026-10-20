part of 'note_templates.dart';

class TechnicalArticleTemplates {
  static const all = <NoteTemplate>[
    NoteTemplate(
      id: 'article_memory',
      name: 'Game memory research article',
      description:
          'Explain a memory observation with build context, structure layouts, controlled experiments and reproducible evidence.',
      icon: Icons.memory_outlined,
      defaultTitle: 'Understanding a game memory structure',
      tags: ['article', 'memory', 'reverse engineering', 'game', 'technical'],
      body: '''## Summary
[Fill in the useful result and who this article helps.]

## Question and scope
[Question: what behaviour or data representation are you investigating?]

## Reproducible environment
| Item | Recorded value |
| --- | --- |
| Game / sample and exact build | [Game / build hash] |
| Architecture and address width | [32-bit / 64-bit] |
| Module and address space | [Module / RVA / virtual / file offset] |
| Tools and versions | [Tools and versions] |
| Test conditions | [Save state, inputs and controls] |

## Observed layout
Use Writing tools → Research diagram for a live memory-layout or pointer-chain diagram. Record offsets, types, alignment, ownership and lifetime separately.

| Offset | Size | Proposed type | Observation | Confidence |
| --- | --- | --- | --- | --- |
| +0x00 | [bytes] | [Type] | [Observation] | Unverified |

## Method and controls
1. Describe the baseline and the exact steps you performed.
2. Change one variable and record the resulting bytes or behaviour.
3. Repeat with a control and document alternative explanations.

## Findings and evidence
[Result: distinguish measurements from inferred meaning. Link annotated figures, traces and source references.]

## Limitations and build changes
Document pointer validity, rebasing, endianness, thread timing, false positives and which conclusions require revalidation.

## Reader takeaway
Explain what the evidence establishes and what remains uncertain.

## Sources and revision history
- [Source title](https://example.com/replace-with-original-source)
- [Date] — initial publication; record substantive corrections here.
''',
    ),
    NoteTemplate(
      id: 'article_reverse',
      name: 'Reverse-engineering case study',
      description:
          'A first-hand investigation from question to function map, hypotheses, evidence and verified conclusions.',
      icon: Icons.biotech_outlined,
      defaultTitle: 'Reverse-engineering a subsystem',
      tags: ['article', 'reverse engineering', 'disassembly', 'research'],
      body: '''## Summary
[Fill in the original finding and practical value.]

## Investigation question
Define the subsystem, expected behaviour and boundaries of this case study.

## Target and reproduction context
Record binary identity, build hash, module, architecture, symbol provenance and tool versions. Distinguish RVA, virtual address and file offset.

## Function and data map
Insert a call-flow diagram with Writing tools → Research diagram. Link source records and label observed versus inferred relationships.

| Function / RVA | Inputs | Outputs / side effects | Supporting evidence |
| --- | --- | --- | --- |
| [Symbol / RVA] | [Inputs] | [Observation] | [Trace or source] |

## Walkthrough
### 1. Establish a baseline
Describe the exact inputs and observable outputs.

### 2. Form a hypothesis
Record confidence, evidence for and against it, and an experiment that could disprove it.

### 3. Validate the interpretation
Show a minimal excerpt with architecture/tool context and explain each relevant step. Preserve enough context to reproduce the result.

## Results and alternatives
[Result: explain what is demonstrated, what is inferred, and competing explanations.]

## Limitations
Record missing symbols, incomplete coverage, compiler effects, build specificity and uncertain types.

## Sources, artifacts and corrections
Link public supporting material and record substantive updates with dates.
''',
    ),
    NoteTemplate(
      id: 'article_binary_diff',
      name: 'Build comparison article',
      description:
          'Compare recorded behaviour and binary findings across builds without confusing rebasing with code changes.',
      icon: Icons.compare_arrows_outlined,
      defaultTitle: 'What changed between two builds',
      tags: ['article', 'reverse engineering', 'binary', 'comparison', 'game'],
      body: '''## Summary
[Fill in the change readers need to understand.]

## Baseline and candidate
| Context | Baseline | Candidate |
| --- | --- | --- |
| Version / binary hash | [Build / hash] | [Build / hash] |
| Module and architecture | [Module] | [Module] |
| Reproduction conditions | [Conditions] | [Conditions] |

## Comparison method
Explain matching criteria, module/base normalization, excluded records and coverage. A moved virtual address alone does not establish a behavioural change.

## Recorded changes
| Symbol / stable identity | Baseline RVA | Candidate RVA | Classification | Evidence |
| --- | --- | --- | --- | --- |
| [Symbol] | [RVA] | [RVA] | [Changed / rebased / unmatched] | [Source] |

## Controlled verification
Show the same test on both builds, expected results, actual observations and supporting artifacts.

## Interpretation and limitations
Separate metadata differences, instruction differences and verified behaviour. Explain ambiguous matches and incomplete data.

## Conclusion and sources
Summarize the verified effect, link original evidence, and record follow-up questions and corrections.
''',
    ),
    NoteTemplate(
      id: 'article_engine',
      name: 'Game systems technical deep dive',
      description:
          'Explain gameplay or engine internals using state/data flow, measurements, implementation excerpts and tradeoffs.',
      icon: Icons.sports_esports_outlined,
      defaultTitle: 'How a game system works',
      tags: [
        'article',
        'game development',
        'engine',
        'technical',
        'performance',
      ],
      body: '''## Summary
[Fill in the system, useful result and intended audience.]

## Problem and constraints
Describe the desired behaviour, platform, engine/build version and relevant assumptions.

## Architecture and data flow
Insert a call-flow or evidence diagram. Explain state ownership, updates and outputs.

## Implementation walkthrough
Show a minimal self-contained excerpt and explain why each part exists. Include language/runtime version and relevant invariants.

## Measurement and verification
| Scenario | Expected | Observed | Environment / evidence |
| --- | --- | --- | --- |
| [Scenario] | [Result] | [Observation] | [Build / trace] |

## Alternatives and tradeoffs
Compare correctness, memory use, latency and maintainability. Describe the measurement method rather than presenting unsupported performance claims.

## Failure cases and limitations
Cover invalid inputs, lifecycle changes, concurrency and platform differences.

## Takeaways and references
Summarize transferable lessons, cite original sources and record corrections.
''',
    ),
  ];
}
