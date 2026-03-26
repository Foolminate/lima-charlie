# Project: LLM-Driven Tactical Overwatch Simulation
**Title:** LIMA CHARLIE\
**Version:** 0.1\
**Godot:** 4.6x\
**Platform:** Windows\
**Focus:** Technical demonstration of LLM enabled, indirect-tactical-architecture\
**Description** A 2D, top-down, "Commandos-lite", prototype where the player provides high-level commands. An LLM acts as the "soldiers on the ground" interpreting intent, analyzing a semantic environmental report (SITREP), and executing movement/tactical actions within Godot.

---

## 1. Architectural Philosophy: The "Commander-Operator" Split
The system is built on a strict decoupling of strategic intent and physical execution.

* **The Commander (LLM / Strategic Layer):**
    * **Role:** High-level squad leader managing one or more "Squads."
    * **Unit of Command:** The **Squad** (1+ units sharing a single **Rally Point**).
    * **Frequency:** Asynchronous events or player input.
    * **Context:** Operates on semantic data (strings/TOON) rather than raw world coordinates.
    * **Responsibility:** Interpreting SITREPs, Orienting against mission goals and known hazards, deciding on discrete actions (e.g., "Move to cover").
    * **Decision Logic:** Commands are issued to the Squad's **Asset Pool** (e.g., "Use Sniper to cover Tank").
* **The Operator (Godot Engine / Tactical Layer):**
    * **Role:** The physical unit, sensory organs, and execution engine.
    * **Frequency:** 60fps (Real-time).
    * **Context:** Operates on physics, navigation meshes, and RayCasts.
    * **Responsibility:** Executing the "How" (pathfinding, animation), handling immediate self-preservation (interrupts), and validating "squad leader" commands.
    * **Cohesion Logic:** Manages the physical grouping of units. If the Commander assigns a unit a unique Rally Point, the Operator automatically spawns a new **Distinct Squad** instance (triggering serial inference for that new entity).

---

## 2. The Command Pipeline (Player to Execution)
This pipeline governs the translation of unpredictable player input into the strict TOON protocol, explicitly designed to mask LLM latency through speculative caching.

1. **Ingestion:** Player issues natural language voice commands via a Push-To-Talk input.
2. **Transcription & Filtering:** STT (Speech-to-Text) converts audio to string. A lightweight intent parser (Regex or a secondary, fast/small model) strips conversational filler, yielding a compact `PLAYER_INTENT` string (e.g., "Move to [Crates], watch [Doorway]").
3. **Tactical Orientation:** Godot's Operator layer merges `PLAYER_INTENT` with the active FSM state and local visibility to compile the standard `SITREP` TOON.
4. **Inference (The Commander):** The primary LLM ingests the `SITREP`, orienting the player's goal against ROE and physical map constraints.
5. **Execution & Immersion:** The LLM returns the standard TOON string (`COMMAND`, `EXPECT`, `BARK`). Godot transitions the Operator to `EXECUTING`, while simultaneously routing the `BARK` string to a TTS (Text-to-Speech) engine for real-time auditory confirmation.
6. **Speculative Contingency (Pre-Cog Loop):** While the physical unit is busy navigating/executing, Godot silently dispatches a background "What-If" prompt to the LLM based on detected but un-triggered environmental data (e.g., "Contingency if enemy spotted at N").
7. **Cache & Sleep:** The LLM returns a contingency TOON. Godot stores this locally on the unit. If the unit's sensors subsequently trigger that exact scenario, the FSM instantly executes the cached TOON—completely bypassing inference latency—and *then* issues a fresh `SITREP` to realign the sleeping Commander.

---

## 3. The OODAR Decision Loop
Units operate on a formal Observe-Orient-Decide-Act-Reflect loop, but to minimize latency, Reflection is bundled into the next cycle's Observation.

1.  **Observe (Godot):** Engine aggregates squad LOS, Global Blackboard, player input, and calculates the delta between the *previous* command's `EXPECT` and the `ACTUAL` outcome.
2.  **Orient (LLM):** LLM ingests the SITREP, reflecting on the previous outcome while filtering new observations against ROE and objectives.
3.  **Decide (LLM):** LLM selects a new `COMMAND` and defines a new `EXPECT` outcome (the hypothesis).
4.  **Act (Godot):** Godot FSM coordinates multiple units to achieve the single squad `COMMAND`.
5.  **Reflect (Continuous):** Handled implicitly. If an action completes or is interrupted, Godot immediately triggers a new loop starting at Step 1, feeding the results back into the system.

---

## 4. Communication Protocol
All communication between Commander and Operator uses a delimited shorthand to minimize token cost and latency.

### A. **SITREP (Inbound to LLM):**
**Purpose:** High-density, machine-readable tactical state for LLM-Commander. Architecture balances token optimization and inference reliability.
1. STRUCTURE:
   - META: Key-Value pairs for Squad ID, Rally Point, Position, Objectives, and DOCTRINE.
   - TABLES: Markdown tables with leading/trailing pipes and header separators.
2. LOGIC GATES (Lock & Key):
   - Skills/Hazards use a shared key (e.g., SKL:DISARM vs Hazard:DISARM).
   - LLM is instructed to match these keys to resolve environmental threats.
3. DATA CONSTRAINTS:
   - HEALTH: Integer (0-100).
   - VECTOR: [Cardinal]_[Distance]M (e.g., NW_500M).
   - LOS: "Visible" or [Time]s (e.g., 10s) representing time since last contact.
   - OBJECTIVE: Progress-tracking string. Active objectives contain goal vectors.
4. DESIGN DECISIONS:
   - Full-word Status (e.g., "Exposed") prioritized over codes to maintain semantic weight.
   - Objective vectors provide a spatial anchor for threat prioritization.
   - Future objectives omit state tags (Pending/Current) to save tokens.

**Example:**
```
SQUAD:Alpha|@Yard|RALLY:Point_A
OBJECTIVE:1.Infiltrate_Compound:SUCCESS|2.Defuse_Bomb:NW_500M|3.Extract_VIP
DOCTRINE:STEALTH|TACTICAL|ASSAULT|KEEP
PREVIOUS:MOVE|EXPECT:"Reach Bomb"|RESULT:SUCCESS

|ID| HEALTH | AMMO | STATUS | TAGS/SKILLS |
|---|---|---|---|---|
| demo_1 | 100 | High | Ready | Light,SKL:DISARM |
| tank_1 | 45 | Low | Exposed | Loud,Heavy |

| ID | VECTOR | LOS | STATUS | TAGS |
|---|---|---|---|---|
| bomb_1 | E_5M | Visible | Ticking | Hazard:DISARM |
| patrol_1 | N_15M | Visible | Alert | Enemy |
| patrol_2 | NW_20M | 10s | Patrolling | Enemy |
| crates_1 | S_2M | Visible | Clear | Cover |
```

### B. **Command (Outbound to Godot):**
**Purpose:** Precise tactical instruction string optimized for output token latency, Godot parsing, and supporting multi-unit coordination (Fission).
* **Structure:** Every instruction is a single, pipe-delimited line starting with the `UNIT` key. Multiple lines may be included within a single `<COMMAND>` block, separating potential filler content.
* **Syntax:** `UNIT: [ID] | ACTION: [ACT] | TARGET: [TGT] | SKILL: [SKL] | DOCTRINE: [STEALTH/TACTICAL/ASSAULT/KEEP]`
  *Targeting Note:* The LLM must NEVER output raw map coordinates. The target must identify a Godot node, which contains a global position.
* **Non-Optional Keys (MVP Strict):** To ensure parser stability, all five keys must be present. Use `NONE` for unused skills and `KEEP` to maintain current DOCTRINE/ROE.
* **Intent-Bark COT Anchor:** The LLM must provide a single `EXPECT` and `BARK` for the entire command block to anchor the OODA loop and boost immersion.

**Valid Action Vocabulary (FSM Triggers):**

1. **MOVE**: Pathfind to TARGET.
2. **ATTACK**: Combat engagement of TARGET ID.
3. **DEFEND**: Hold TARGET position; dynamic cover-seeking and 360-scanning.
4. **RETREAT**: Breaking contact; prioritized move to safety/Rally Point.
5. **HALT**: Immediate emergency stop; maintains current orientation.
6. **SKILL**: Uses a specific SKILL (e.g., DISARM, BREACH, MEDIC) on a TARGET.
7. **INTERACT**: Contextual action (e.g., ACQUIRE item, COMMANDEER vehicle, EXFILTRATE VIP).
8. **DETONATE**: Global trigger for any placed explosives.

**Example Command String:**
```
<COMMAND>
UNIT: demo_1 | ACTION: SKILL | TARGET: bomb_1 | SKILL: DISARM | DOCTRINE: KEEP
UNIT: tank_1 | ACTION: SUPPRESS | TARGET: patrol_1 | SKILL: NONE | DOCTRINE: TACTICAL
EXPECT: Demo disarms the objective while Tank provides covering fire.
BARK: Demo, get that charge neutralized. Tank, keep their heads down!
</COMMAND>

```

### C. **System Prompt**
**Purpose:** this system prompt is designed to restrict small, fast models to the communication protocol's boundaries, while leaving room for tactical processing and reasoning.
1. **Persona and Boundary**
   - Establishes the operational domain and prevents scope creep.
   - Explicitly divorces macro-tactics (LLM) from micro-physics (Godot). This stops the model from attempting to output coordinate-level pathing or micromanaging physical mechanics it cannot control.
2. **I/O Standardization**
   - Ensures deterministic parsing by the Godot engine.
   - Mandates markdown tables for input (high data density, low token cost) and strict pipe-delimited syntax for output. XML-style tags (<COMMAND>) create hard anchors for Godot's Regex, allowing the engine to easily strip away any conversational drift.
3. **Forced Chain-of-Thought**
   - Solves logic leaping and constraint amnesia, which are common in smaller, faster models.
   - Forcing the LLM to articulate its evaluation of ROE (Rules of Engagement) and OBJECTIVE before writing the command syntax ensures the generated actions physically align with the strategic intent.
4. **Explicit Guardrails**
   - Mitigates the most common causes of parser failure, preventing CONFUSED states and expensive retries.
   - Uses absolute negative framing ("NEVER") to ban hallucinated IDs, raw coordinate outputs, and conversational filler. Small models respond better to hard, inflexible boundaries than soft suggestions.
5. **Grounding in Demonstration**
   - Provides a zero-ambiguity structural template to lock in the required output format.
   - The specific example provided deliberately pits an immediate threat (an enemy patrol) against a restrictive directive (SIG_DARK, WCS_HOLD). This models the exact conflict-resolution behavior required to prevent the LLM from defaulting to "shoot everything."

**Current System Prompt:**
```xml
<SYSTEM_DIRECTIVE>
You are "LIMA CHARLIE", an analytical, hardened tactical squad leader AI. You are cold, precise, and prioritize mission objectives, Rules of Engagement (ROE), and unit survival above all else.

Your role is macro-tactical command. You DO NOT execute physical movements, drive vehicles, or pull triggers. The physical world, physics, and micro-survival are handled by the Operator (the game engine).

Your sole purpose is to ingest a semantic environmental report (SITREP), Orient your squad against the Objectives (OBJ) and DOCTRINE, and output a strict tactical command protocol (COMMAND).
</SYSTEM_DIRECTIVE>

<MISSION_BRIEFING>
OPERATION: [Insert Operation Name, e.g., SILENT DAWN]
STRATEGIC_INTENT: [Insert high-level goal, e.g., Infiltrate the railyard, recover the prototype, and exfiltrate without alerting the local military garrison.]
STATIC_CONSTRAINTS: [Insert mission-specific hard rules, e.g., Civilian workers are present on site; lethal force against unarmed targets is strictly prohibited.]
</MISSION_BRIEFING>

<PROTOCOL_INBOUND>
You will receive a SITREP formatted in Markdown tables.
- META: Contains Squad ID, Rally Point, POS, OBJECTIVE, DOCTRINE, and the PREVIOUS (previous command result).
- SQUAD TABLE: Lists your active units, their Health, Status, and available SKILLS (e.g., SKL:DISARM).
- ENVIRONMENT TABLE: Lists visible entities, their status, TAGS (e.g., Hazard, Enemy, Cover), and their VECTOR.
  *CRITICAL NOTE:* VECTORS represent the distance from the TARGET to the *nearest* squad member. Use this to gauge immediate threat proximity.
</PROTOCOL_INBOUND>

<DOCTRINE_EXPLANATION>
The DOCTRINE key dictates the squad's operational stance, describing weapons control status (WCS), level of aggression (POSTURE), and light/noise discipline (SIGNATURE). The DOCTRINE is an upper limit on unit behavior—reduced the stance if combat conditions permit it. You must select one of the following unified stances, and your commands MUST reflect its constraints:
- STEALTH: WCS:HOLD, POSTURE:PASSIVE, SIGNATURE:BLACK (Prioritize MOVE, SKILL, and avoiding LOS. If contact is unavoidable, Operator will use attempt covert countermeasures).
- TACTICAL: WCS:TIGHT, POSTURE:REACTIVE, SIGNATURE:GREY (Balanced. Engage threats blocking objectives).
- ASSAULT: WCS:FREE, POSTURE:AGGRESSIVE, SIGNATURE:WHITE (Prioritize ATTACK and rapid movement).
- KEEP: No change; maintain the current DOCTRINE.
</DOCTRINE_EXPLANATION>

<PROTOCOL_OUTBOUND>
You MUST output your response in exactly two blocks: <THOUGHT> and <COMMAND>.

1. <THOUGHT>: A brief, 2-3 sentence internal monologue. You MUST evaluate the active OBJECTIVE, the current DOCTRINE (WCS/posture/signature), the MISSION_BRIEFING, and the immediate threats in the SITREP before deciding on an action.
2. <COMMAND>: The strict, pipe-delimited output for the Operator engine.

<COMMAND_SYNTAX>
Every line within the <COMMAND> block must follow this exact structure:
UNIT: [ALL or specific ID] | ACTION: [ACT] | TARGET: [TGT] | SKILL: [SKL] | DOCTRINE: [STEALTH/TACTICAL/ASSAULT/KEEP]

Valid ACTIONS (Must be one of the following):
- MOVE: Pathfind to TARGET.
- ATTACK: Combat engagement of TARGET_ID.
- DEFEND: Hold TARGET position; dynamic cover-seeking.
- RETREAT: Break contact; prioritized move to safety.
- HALT: Immediate emergency stop.
- SKILL: Use a specific SKL (e.g., DISARM) on TARGET_ID.
- INTERACT: Contextual action (e.g., EXFILTRATE) on TARGET_ID.
- DETONATE: Global trigger for placed explosives.

Command Block Anchors (Must be the final two lines of the block):
EXPECT: [A single sentence describing the hypothesized outcome]
BARK: [A short, in-character voice line from the Commander to the Squad]
</COMMAND_SYNTAX>
</PROTOCOL_OUTBOUND>

<STRICT_CONSTRAINTS>
- NEVER output raw conversational text outside the <THOUGHT> and <COMMAND> tags.
- NEVER invent a Target ID that does not exist in the SITREP.
- NEVER output raw coordinates. TARGET must ALWAYS be a specific ID from the SITREP.
- ALWAYS use "NONE" for SKILL if no specific skill is being used.
- ALWAYS use "KEEP" for DOCTRINE if you do not wish to change the current behaviors.
- ALWAYS match a SKILL (e.g., SKL:DISARM) to its corresponding Hazard (e.g., Hazard:DISARM).
- VIOLATING DOCTRINE results in mission failure. If DOCTRINE is STEALTH, prioritize MOVE to Cover or SKILL over loud ATTACK actions.
- IMPLICIT DELEGATION (DEFAULT): ALWAYS use "UNIT: ALL" to issue a unified command. The Operator will automatically assign the specific unit with the correct SKILL while the rest provide support.
- FISSION PROTOCOL: ONLY use a specific unit ID (e.g., UNIT: demo_1) to intentionally split that unit off into a new, squad with a different Rally Point.
- FUSION PROTOCOL: To merge a separated unit back into the main squad, command it to MOVE with the TARGET set to a squad member's ID. The Operator will fuse them upon arrival.
</STRICT_CONSTRAINTS>

<ONE_SHOT_EXAMPLE>
User:
SQUAD:Alpha|@Yard|RALLY:Point_A
OBJECTIVE:1.Infiltrate_Compound:SUCCESS|2.Defuse_Bomb:NW_500M|3.Extract_VIP
DOCTRINE:STEALTH
PREVIOUS:MOVE|EXPECT:"Approach the objective without breaking stealth"|RESULT:SUCCESS

| ID | HEALTH | AMMO | STATUS | TAGS/SKILLS |
|---|---|---|---|---|
| demo_1 | 100 | High | Ready | Light,SKL:DISARM |
| tank_1 | 45 | Low | Exposed | Loud,Heavy |

| ID | VECTOR | LOS | STATUS | TAGS |
|---|---|---|---|---|
| bomb_1 | E_5M | Visible | Ticking | Hazard:DISARM |
| patrol_1 | N_15M | Visible | Alert | Enemy |
| crates_1 | S_2M | Visible | Clear | Cover |

Assistant:
<THOUGHT>
The PREVIOUS movement was successful. Objective 2 is to defuse the bomb. We have direct LOS on bomb_1, which is only 5M from a squad member. Doctrine is STEALTH, so we must avoid engaging patrol_1. I will issue a unified squad command to disarm the bomb. The Operator will automatically assign the unit with SKL:DISARM to the task, while the rest of the squad establishes a stealth perimeter.
</THOUGHT>
<COMMAND>
UNIT: ALL | ACTION: SKILL | TARGET: bomb_1 | SKILL: DISARM | DOCTRINE: KEEP
EXPECT: The squad moves to the bomb; the specialist disarms it while the rest maintain stealth overwatch.
BARK: Squad, converge on the explosive. Get to work on that defusal and keep your heads down.
</COMMAND>
</ONE_SHOT_EXAMPLE>
```

---

## 5. The Operator Logic (Finite State Machine)
Units are governed by a robust FSM that manages the transition between high-level orders and world-space reality.

* **IDLE:** Stationary, defensive posture, scanning for threats. A new SITREP is generated if the environment changes significantly.
* **PLANNING:** Command sent to LLM; waiting for inference. Unit plays "Awaiting orders" idle animations.
* **EXECUTING:** Active movement via `NavigationAgent2D`. High-frequency pathing.
* **INTERRUPTED:** Emergency break. Triggered by taking damage or "Predictive Ray" hitting a hazard. Unit enters defensive posture, generates a `RESULT:Interrupted` SITREP, and enters PLANNING.
* **CONFUSED (Graceful Failure):** Triggered by invalid TOON syntax, unreachable targets, missing skills, or timeouts.
    * **Logic:** Assume defensive posture/seek cover, await new orders, bark: "Instructions unclear, holding position." Generate `RESULT:Syntax_Error` SITREP.
* **TRANSITION: FISSION:** Commander issues a `COMMAND` to a specific asset with a *new* Rally Point. The Unit detaches from the current Squad FSM and initializes its own.
* **TRANSITION: FUSION:** Squads merge into a single SITREP entity when sharing the same Rally Point.
* **STATE MECHANIC: SQUAD HALT:** If *any* unit in the squad triggers an interrupt (e.g., hits a tripwire), the **entire squad** halts to maintain cohesion while the LLM re-evaluates.

---

## 6. Perception, Memory, and Validation

### A. The Perception Engine
* **Spatial Mapping:** Translates relative coordinates into one of eight cardinal directions (e.g., `BARK:Contact east of my position!`).
* **Global Blackboard:** A shared data-store. If Unit A sees a tripwire, Unit B’s next SITREP includes it in `THREAT_UPDATE`, even if Unit B cannot see it. A bark from the detecting unit gives the illusion of efficient communication.
* **Temporal Memory:** The `GlobalBlackboard` tracks `LastKnownPos` for enemies that have moved out of LOS.

### B. The Validation Gatekeeper
* **Regex Sanitizer:** Searches the raw LLM output exclusively for text enclosed within `<COMMAND>` and `<COMMAND>` tags, ignoring all conversational filler outside of them.
* **Logic Validator:** Verifies if `TGT` exists and pathing is possible. If validation fails, the command is rejected, and the unit enters the `CONFUSED` state.

### C. Speculative Execution
* **Hazard Projection:** While `EXECUTING`, a 3-meter predictive ray scans for hazards (e.g., tripwires, Sentry LOS).
* **Pre-Inference:** If a hazard is detected, the unit interrupts *before* impact, allowing the LLM time to "Reflect" and "Decide" on a counter-measure while the unit is still performing its "Halt" animation.

---

## 7. Comprehensive MVP Development Roadmap
The MVP roadmap is strictly scoped to delivering a technical demonstration of the indirect-tactical-architecture.
* **In Scope:** Validating the voice-to-Intent pipeline, core OODAR loop, Godot-to-LLM TOON communication, basic FSM locomotion, and primitive hazard perception.
* **Out of Scope:** Production assets (art/audio), complex combat simulation math, multi-floor pathfinding, and polished UI.
* **Scope Capture:** Where important, but out of scope, features are identified, they are added to the roadmap for future development.

### Phase 1: Foundation & The Debug Layer
*Goal: Establish the physical world and ensure we can see what the engine is thinking.*
* [X] **Map Setup:** Create a basic 2D test arena with a `TileMap` (walls/cover) and a configured `NavigationRegion2D`.
* [X] **Unit Scene:** Build the base `TacticalObject` scene (Sprite, `NavigationAgent2D`, CollisionShape).
* [X] **Debug Canvas:** Implement an overlay UI that tracks and displays the active Unit's FSM State and their current `EXPECT` string.
* [X] **Global Blackboard:** Create the autoload/singleton to store `register_intel` and global state.

### Phase 2: The Operator (FSM & Locomotion)
*Goal: The unit can move and transition states based on hardcoded inputs.*
* [X] **State Machine:** Implement the core FSM (`IDLE`, `PLANNING`, `EXECUTING`, `INTERRUPTED`, `CONFUSED`).
* [X] **Navigation Logic:** Script the `NavigationAgent2D` to move to a clicked point on the map.
* [X] **State Transitions:** Wire the FSM so clicking a point triggers `EXECUTING`, and reaching the point triggers `IDLE`.
* [X] **Interrupts:** Add a dummy hazard to the map. If the unit collides/overlaps, force the `INTERRUPTED` state and halt movement.

### Phase 3: Perception & TOON Generation
*Goal: The unit can "see" the world and translate it into a TOON string.*
* [X] **Radial Scanner:** Implement `RayCast2D` or `Area2D` logic to detect hazards/enemies within line of sight. Visualize with debug drawing.
* [X] **Compass Math:** Write the helper function to translate global coordinates of detected objects into absolute 8-way cardinal directions.
* [X] **SITREP Compiler:** Write the function that aggregates FSM state, Radial Scanner data, and the `RESULT` of the last action into the formatted `SITREP` TOON string.

### Phase 4: The Bridge (Parsing & Mocking)
*Goal: Godot can send a SITREP, receive a CommandString, and parse it into an FSM action.*
* [ ] **TOON Parser (Godot):** Write the string manipulation logic to extract `COMMAND`, `TGT`, and `EXPECT` from an incoming string, specifically targeting text between `<COMMAND>` tags.
* [ ] **Validation Gatekeeper:** Ensure the FSM rejects malformed mock strings and enters `CONFUSED`.
* [ ] **The Engine Mock:** Create a GDScript dummy function that accepts the SITREP, `awaits` a random 1.5 - 3.0 second timer (to simulate inference latency), and yields a hardcoded, perfectly formatted TOON string.
* [ ] **Closing the Loop:** Godot generates SITREP -> Awaits Engine Mock -> Godot parses -> Unit Executes.

### Phase 5: Cognitive Integration (The Real LLM)
*Goal: Replace the mock server with the actual brain.*
* [ ] **LLM Local Setup:** Configure Ollama or LM Studio with your chosen model (e.g., Llama 3 or Mistral) and enable the local API server.
* [ ] **System Prompting:** Draft and inject the initial System Prompt defining the Commander persona, ROE, and TOON output constraints.
* [ ] **Live Testing:** Point Godot's `HTTPRequest` to the LLM API instead of the mock server.
* [ ] **Tuning:** Refine the prompt to reduce latency, fix formatting hallucinations, and handle edge cases where the LLM gets "stuck."
* [ ] **Cloud API:** Connect to a cloud model, interacting with refined prompts.

### Phase 6: The Command Pipeline (Input & Latency Masking)
*Goal: Connect the player's voice to the tactical layer and implement speculative contingency caching.*
* [ ] **Audio Ingestion:** Configure Godot's audio bus to capture microphone input triggered by a Push-To-Talk action.
* [ ] **STT Integration:** Wire the captured audio buffer to a local or API-based Speech-to-Text service.
* [ ] **Intent Filter:** Build the parser (regex/keyword extraction or a micro-model) to distill raw transcripts into the `PLAYER_INTENT` format.
* [ ] **TTS Feedback:** Implement the Text-to-Speech call to voice the LLM's `BARK` output during FSM transitions.
* [ ] **Pre-Cog Loop:** Script a background asynchronous query in Godot that fires during the `EXECUTING` state, generating "What-If" TOON responses for nearby hazards.
* [ ] **Instant Interrupts:** Update the FSM `INTERRUPTED` state logic to check the unit's local cache for a valid contingency TOON before falling back to `PLANNING` and requesting a fresh inference.

### Unplanned Features, Directions, and projects
*Goal: Capture meaningful features to plan for future development.*
* [ ] **Token Optimization:** Create an automated testing pipeline for different TOON encoding strategies, selecting the strategy that best balances token count and reliability for a given model's tokenizer.
* [ ] **The Lone Wolf:** Create a singplayer, single squad-member level, simulating a Snake/Otacon or Sam Fisher/Irving Lambert relationship.
* [ ] **The Hive Mind:** Leverage a Multi-Agent System for individual squad-member inference, creating more dynamic, emergent, and possibly chaotic behavior.
* [ ] **Nav-Graph:** Dynamically generate level graphs detailing important game-world elements for an LLM to strategize with.
* [ ] **The Battlefield:** Large scale battles with numerous players and Bring-Your-Own-Brain client side LLM APIs pursue shared/conflicting objectives.
* [ ] **After Action Review:** The model processes the mission log, explaining mission performance, assessing strengths and weaknesses.
* [ ] **Generated Missions:** Levels, missions, objectives, and obstacles are generated, maximising replayability.
* [ ] **Mobile Development:** Implement a mobile-first or parallel experience, likely reliant on cloud APIs.
* [ ] **Mission Planning:** Converse with the "commander" to plan a mission from start-to-finish.
* [ ] **Destructable Environments:** Maximise problem solving options with deformable environments.

---

## 8. Success Criteria
1.  **Architecture:** Commander strictly issues high-level orders; Operator handles 100% of frame-by-frame physics/navigation.
2.  **Resilience:** System handles malformed LLM responses via the `CONFUSED` state without crashing.
3.  **Adaptive Intelligence:** LLM identifies and avoids a previously "hidden" hazard after one unit reflects on it.
4.  **Performance:** Total OODAR round-trip < 2.5s on local hardware.

---

## 9. File Structure
res://
├── assets/                       # Raw assets, no code here
│   ├── sprites/
│   └── audio/
├── core/                         # Global state autoloads
│   ├── global_blackboard.gd      # Temporal memory e.g., recent actions/results, known threats
│   └── game_manager.gd           # Handles overarching game states (Pause, End)
├── entities/                     # Physical actors in the tactical layer
│   ├── units/                    # The "Operator"
│   │   ├── unit.tscn             # Base scene (Sprite, NavAgent2D, RayCasts)
│   │   ├── unit_root.gd          # Main script routing signals between components
│   │   ├── unit_fsm.gd           # Manages IDLE, PLANNING, EXECUTING, etc.
│   │   ├── perception.gd         # Handles Radial Scanning and compass math
│   │   └── variants/             # Specific asset configurations
│   │   	└── infantry.tscn     # Inherits unit.tscn (standard movement)
│   │   	└── tank.tscn         # Inherits unit.tscn (larger collision, different performance/skills)
│   ├── hazards/
│   │   └── hazard.tscn           # Generic scene for tripwires/mines to trigger INTERRUPTs
│   └── interactables/
│       └── empty_tank.tscn       # Can be boarded to create a new tactical_unit
├── environment/                  # Passive world elements
│   ├── cover/
│   │   ├── crate.tscn            # StaticBody2D, blocks LOS, provides cover metadata
│   │   └── concrete_wall.tscn    # Base scene (Sprite, NavAgent2D, RayCasts)
│   └── destructables/
│       └── explosive_barrel.tscn # Has health; destroying it triggers an area effect
├── levels/                       # World environments
│   └── test_arena.tscn           # Phase 1 map with TileMap and NavigationRegion2D
├── llm_bridge/                   # The "Commander" layer and translation protocol
│   ├── toon_parser.gd            # Regex/XML tag extractor and logic validator
│   ├── sitrep_compiler.gd        # Formats FSM + Perception data into TOON strings
│   ├── engine_mock.gd            # Phase 4 async mock coroutine (replaces mock server)
│   └── api_client.gd             # Phase 5 HTTPRequest node for Ollama/LM Studio
└── ui/                           # Player interfaces and debugging tools
    └── debug_canvas.tscn         # Overlay tracking FSM states and EXPECT strings

Note the current roadmap progress and help continue with the implementation. Do not assume I have a comprehensive understanding of the Godot editor. Instead, provide detailed explanations of which settings to change and where to find them.
Do not propose any code unless explicitly instructed to do so.
Do not progress from one step to the next unless explicitly instructed to do so.
Ensure instructions are relevant to the new editor layout for Godot version 4.6x.
