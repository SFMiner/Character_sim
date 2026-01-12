# Dialogue Simulator - Godot 4.5 Project

A deterministic character dialogue simulator implementing the v4.0 spec with extensible interfaces for future personality/drive systems.

## Quick Start

1. Open in Godot 4.5
2. Run `main.tscn` (LLM-type character: Archivist-7)
3. Or run `human_npc.tscn` (Human-type character: Old Marcus)
4. Try these queries:
   - "Where is the blacksmith?"
   - "Where is the blacksmieth?" (typo - still works!)
   - "Who is the king?"
   - "Who are you?" (self-knowledge)
   - "Tell me about the tavern"
   - "What about magic?" (forbidden topic for Archivist-7)
   - Ask a follow-up: "What about it?" (tests coreference)

## Project Structure

```
dialogue_sim/
|- knowledge/                    # Epistemic backend
|  |- fact_resource.gd           # Semantic content (never dialogue-ready)
|  |- world_knowledge_resource.gd # Canonical truth archive
|  |- world_knowledge_autoload.gd # Singleton with sample facts
|  |- npc_memory_resource.gd     # Subjective beliefs (duplicated per NPC)
|  |- npc_memory_old_marcus.tres  # Old Marcus beliefs
|  |- npc_memory_archivist_7.tres # Archivist-7 beliefs
|
|- dialogue/                     # Dialogue pipeline
|  |- speech_act_interpreter.gd  # Classifies input type
|  |- context_state.gd           # Coreference resolution
|  |- decision_gate.gd           # Decides WHAT to do (share/refuse/deflect)
|  |- skeleton_engine.gd         # Selects response structure
|  |- template_rewriter.gd       # Safe variation only
|  |- formatter.gd               # Final assembly
|  |- dialogue_manager.gd        # Pipeline orchestrator
|  |- character_node.gd          # Main NPC node
|  |- character_profile.gd       # Static character definition
|  |- npc_state.gd               # Runtime mutable state
|
|- ui/
|  |- dialogue_ui.gd             # Simple test UI
|
|- data/
|  |- skeletons.json             # Response structure templates
|
|- main.tscn                     # LLM character scene
|- human_npc.tscn                # Human character scene
|- project.godot
```

## NPC Memory Files

NPC beliefs are stored as `.tres` resources:
- `knowledge/npc_memory_old_marcus.tres`
- `knowledge/npc_memory_archivist_7.tres`

Edit these files (or create new ones) to change what each character knows or believes.

## Pipeline Flow

```
Player Input
     ↓
SpeechActInterpreter (classify: ASK_ABOUT, REQUEST_HELP, etc.)
     ↓
ContextState (resolve "it", "they" → recent subject)
     ↓
KnowledgeAdapter (query belief, not truth)
     ↓
DecisionGate (decide: SHARE, REFUSE_FORBIDDEN, REFUSE_UNKNOWN, etc.)
     ↓
SkeletonEngine (select preamble/body/postamble structure)
     ↓
Formatter (assemble with content)
     ↓
TemplateRewriter (safe variation)
     ↓
Response
```

## Key Design Principles

### 1. Belief Overrides Truth
If an NPC has misinformation, they speak the false belief:
```gdscript
# In npc_memory_resource:
misinformation = {4: "the King | is named | Aldric the Wise"}  # Truth: Aldric III
```

### 2. Facts Are Never Dialogue
Raw facts like `"blacksmith | is located in | Market District"` are transformed by the pipeline - they never appear directly in output.

### 3. LLM vs Human Voice
- **LLM type**: Structured output, hedging, policy-style refusals
- **Human type**: Direct, terse, natural speech patterns

### 4. Memory Duplication
Each NPC instance gets a **duplicate** of their memory resource. Changes to one NPC don't affect others.

## Extension Points

Every component has documented extension points for future features:

| Component | Extension | What It Enables |
|-----------|-----------|-----------------|
| `FactResource` | granularity, prerequisites | Knowledge gating |
| `NPCMemoryResource` | source_trust, generation | Hearsay chains |
| `CharacterProfile` | warmth, assertiveness, etc. | Full personality |
| `NPCState` | stress, mood, relationships | Dynamic state |
| `DecisionGate` | drive evaluation | Decision-making based on self-interest |
| `SkeletonEngine.get_candidates()` | personality scoring | Multi-candidate selection |

To enable an extension, search for `## EXTENSION POINT` in the code and uncomment the relevant sections.

## Testing Coreference

1. Ask: "Where is the blacksmith?"
2. Then ask: "What about it?" or "Tell me more about that"
3. The system should resolve "it/that" to "blacksmith"

## Testing Forbidden Topics

Archivist-7 refuses to discuss magic:
- "Tell me about magic" → Refusal skeleton
- "What spells do you know?" → Refusal skeleton

## Testing Misinformation

Old Marcus believes the king is named "Aldric the Wise" (truth: Aldric III):
- Ask Old Marcus: "Who is the king?"
- He'll give the wrong name with confidence

## Debug Mode

Click the "Debug" button to see:
- Speech act classification
- Subject extraction
- Coreference resolution
- Knowledge lookup results
- Decision made

## NPC Memory Viewer

Both scenes include a memory panel that lets you inspect NPC belief resources:
- Toggle it with the "Show" button in the header.
- Filter by NPC name, fact id, certainty, or raw content.
- Sort by NPC, fact id, certainty, or raw content (ascending or descending).
- Use "Refresh" if you edit memory resources while the game is running.

The panel aggregates every `knowledge/npc_memory_*.tres` file and maps belief IDs to the `WorldKnowledge` raw facts.

## Sample Facts in World Knowledge

| ID | Tags | Content |
|----|------|---------|
| 1 | location, blacksmith | the blacksmith is located in the Market District |
| 2 | location, tavern | The Rusty Sword tavern stands near the city gates |
| 3 | location, temple | the Temple of Dawn overlooks the city from the eastern hill |
| 4 | person, king | the King is named Aldric III |
| 5 | person, captain | the Captain of the Guard is Helena Ironhand |
| 6 | person, merchant | the Merchant Guild is led by Master Tobias |
| 7 | history, war | The Great War ended one hundred years ago |
| 8 | legend, dragon | the last dragon was slain by the First King |
| 9 | secret, king | King Aldric suffers from a wasting sickness |
| 10 | identity, old marcus | I am Old Marcus, a veteran of the city watch |
| 11 | identity, archivist-7 | I am Archivist-7, a knowledge repository system |

## Features

### Fuzzy Matching (Typo Tolerance)
The system uses Levenshtein distance to handle common misspellings:
- "blacksmieth" → matches "blacksmith"
- "tavrn" → matches "tavern"
- Edit distance of 2 or less is accepted (1 for short words)

### Self-Knowledge
NPCs can answer "Who are you?" questions:
- Recognizes patterns like "who are you", "what's your name", "tell me about yourself"
- Maps to the NPC's identity fact in their memory

### Forbidden Topics (Fixed)
Forbidden topic matching now works correctly:
- Only triggers when the forbidden phrase appears in the query
- "king" no longer triggers "king illness" as forbidden

## License

This is a demonstration project for educational purposes.

