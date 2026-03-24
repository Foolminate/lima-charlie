# Project: LLM-Driven Tactical Overwatch Simulation
**Title:** LIMA CHARLIE
**Version:** 0.1
**Godot:** 4.6
**Platform:** Windows
**Focus:** Technical demonstration of LLM enabled, indirect-tactical-architecture
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
5. **Execution & Immersion:** The LLM returns the standard TOON string (`CMD`, `EXPECT`, `BARK`). Godot transitions the Operator to `EXECUTING`, while simultaneously routing the `BARK` string to a TTS (Text-to-Speech) engine for real-time auditory confirmation.
6. **Speculative Contingency (Pre-Cog Loop):** While the physical unit is busy navigating/executing, Godot silently dispatches a background "What-If" prompt to the LLM based on detected but un-triggered environmental data (e.g., "Contingency if enemy spotted at 12_OCLOCK").
7. **Cache & Sleep:** The LLM returns a contingency TOON. Godot stores this locally on the unit. If the unit's sensors subsequently trigger that exact scenario, the FSM instantly executes the cached TOON—completely bypassing inference latency—and *then* issues a fresh `SITREP` to realign the sleeping Commander.

---

## 3. The OODAR Decision Loop
Units operate on a formal Observe-Orient-Decide-Act-Reflect loop, but to minimize latency, Reflection is bundled into the next cycle's Observation.

1.  **Observe (Godot):** Engine aggregates squad LOS, Global Blackboard, player input, and calculates the delta between the *previous* command's `EXPECT` and the `ACTUAL` outcome.
2.  **Orient (LLM):** LLM ingests the SITREP, reflecting on the previous outcome while filtering new observations against ROE and objectives.
3.  **Decide (LLM):** LLM selects a new `CMD` and defines a new `EXPECT` outcome (the hypothesis).
4.  **Act (Godot):** Godot FSM coordinates multiple units to achieve the single squad `CMD`.
5.  **Reflect (Continuous):** Handled implicitly. If an action completes or is interrupted, Godot immediately triggers a new loop starting at Step 1, feeding the results back into the system.

---

## 4. Communication Protocol: TOON (Token-Optimized Object Notation)
All communication between Commander and Operator uses a delimited shorthand to minimize token cost and latency.

* **SITREP (Inbound to LLM):**
    * `SQUAD:[ID|State]  @[Zone] RALLY:[Point_A] ASSETS:[Sniper, Tank, Medic]`
    * `VIS:[ObjID(Dist,Clock,Type,Status)]`
    * `RESULT:[Success/Interrupt_Reason] (PREV_EXPECT:"[String from last CMD]")`
* **CommandString (Outbound to Godot):**
    * `CMD:[Action] SKILL:[Unit/All ability] TGT:[ObjID/Semantic_Vector] EXPECT:[Hypothesis] BARK:[Voice]`
      * *Targeting Note:* The LLM must NEVER output raw map coordinates. `Semantic_Vector` must be a known engine-parsed string (e.g., `DIR:12_OCLOCK_10M` or `NODE:Alpha`).
    * *Example:* `CMD:FLANK_LEFT SKILL:[Tank_Bounding_Overwatch] EXPECT:"Squad reaches Point_A without casualties" BARK:Tank_ID support by fire! Squad flank left, danger close!`

---

## 5. The Operator Logic (Finite State Machine)
Units are governed by a robust FSM that manages the transition between high-level orders and world-space reality.

* **IDLE:** Stationary, defensive posture, scanning for threats. A new SITREP is generated if the environment changes significantly.
* **PLANNING:** Command sent to LLM; waiting for inference. Unit plays "Awaiting orders" idle animations.
* **EXECUTING:** Active movement via `NavigationAgent2D`. High-frequency pathing.
* **INTERRUPTED:** Emergency break. Triggered by taking damage or "Predictive Ray" hitting a hazard. Unit enters defensive posture, generates a `RESULT:Interrupted` SITREP, and enters PLANNING.
* **CONFUSED (Graceful Failure):** Triggered by invalid TOON syntax, unreachable targets, missing skills, or timeouts.
    * **Logic:** Assume defensive posture/seek cover, await new orders, bark: "Instructions unclear, holding position." Generate `RESULT:Syntax_Error` SITREP.
* **TRANSITION: FISSION:** Commander issues a `CMD` to a specific asset with a *new* Rally Point. The Unit detaches from the current Squad FSM and initializes its own.
* **TRANSITION: FUSION:** Squads merge into a single SITREP entity when sharing the same Rally Point.
* **STATE MECHANIC: SQUAD HALT:** If *any* unit in the squad triggers an interrupt (e.g., hits a tripwire), the **entire squad** halts to maintain cohesion while the LLM re-evaluates.

---

## 6. Perception, Memory, and Validation

### A. The Perception Engine
* **Spatial Mapping:** Translates coordinates into a relative 12-hour clock face based on Global North or Unit Forward.
* **Global Blackboard:** A shared data-store. If Unit A sees a tripwire, Unit B’s next SITREP includes it in `THREAT_UPDATE`, even if Unit B cannot see it.
* **Temporal Memory:** The `GlobalBlackboard` tracks `LastKnownPos` for enemies that have moved out of LOS.

### B. The Validation Gatekeeper
* **Regex Sanitizer:** Searches the raw LLM output exclusively for text enclosed within `<TOON>` and `</TOON>` tags, ignoring all conversational filler outside of them.
* **Logic Validator:** Verifies if `TGT` exists and pathing is possible. If validation fails, the command is rejected, and the unit enters the `CONFUSED` state.

### C. Speculative Execution
* **Hazard Projection:** While `EXECUTING`, a 3-meter predictive ray scans for hazards (e.g., tripwires, Sentry LOS).
* **Pre-Inference:** If a hazard is detected, the unit interrupts *before* impact, allowing the LLM time to "Reflect" and "Decide" on a counter-measure while the unit is still performing its "Halt" animation.

---

## 7. Comprehensive MVP Development Roadmap
The MVP roadmap is strictly scoped to delivering a technical demonstration of the indirect-tactical-architecture.
* **In Scope:** Validating the core OODAR loop, Godot-to-LLM TOON communication, basic FSM locomotion, primitive hazard perception, and the Voice-to-Intent pipeline.
* **Out of Scope:** Production assets (art/audio), complex combat math, multi-floor pathfinding, and polished UI.

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
* [ ] **Radial Scanner:** Implement `RayCast2D` or `Area2D` logic to detect hazards/enemies within line of sight. Visualized these with debug drawing.
* [ ] **Clock-face Math:** Write the helper function to translate global coordinates of detected objects into relative 12-hour clock directions.
* [ ] **SITREP Compiler:** Write the function that aggregates FSM state, Radial Scanner data, and the `RESULT` of the last action into the formatted `SITREP` TOON string. Output this string to the Debug Canvas.

### Phase 4: The Bridge (Parsing & Mocking)
*Goal: Godot can send a SITREP, receive a CommandString, and parse it into an FSM action.*
* [ ] **TOON Parser (Godot):** Write the string manipulation logic to extract `CMD`, `TGT`, and `EXPECT` from an incoming string, specifically targeting text between `<TOON>` tags.
* [ ] **Validation Gatekeeper:** Ensure the FSM rejects malformed mock strings and enters `CONFUSED`.
* [ ] **The Engine Mock:** Create a GDScript dummy function that accepts the SITREP, `awaits` a random 1.5 - 3.0 second timer (to simulate inference latency), and yields a hardcoded, perfectly formatted TOON string.
* [ ] **Closing the Loop:** Godot generates SITREP -> Awaits Engine Mock -> Godot parses -> Unit Executes.

### Phase 5: Cognitive Integration (The Real LLM)
*Goal: Replace the mock server with the actual brain.*
* [ ] **LLM Local Setup:** Configure Ollama or LM Studio with your chosen model (e.g., Llama 3 or Mistral) and enable the local API server.
* [ ] **System Prompting:** Draft and inject the initial System Prompt defining the Commander persona, ROE, and TOON output constraints.
* [ ] **Live Testing:** Point Godot's `HTTPRequest` to the LLM API instead of the mock server.
* [ ] **Tuning:** Refine the prompt to reduce latency, fix formatting hallucinations, and handle edge cases where the LLM gets "stuck."

### Phase 6: The Command Pipeline (Input & Latency Masking)
*Goal: Connect the player's voice to the tactical layer and implement speculative contingency caching.*
* [ ] **Audio Ingestion:** Configure Godot's audio bus to capture microphone input triggered by a Push-To-Talk action.
* [ ] **STT Integration:** Wire the captured audio buffer to a local or API-based Speech-to-Text service.
* [ ] **Intent Filter:** Build the parser (regex/keyword extraction or a micro-model) to distill raw transcripts into the `PLAYER_INTENT` format.
* [ ] **TTS Feedback:** Implement the Text-to-Speech call to voice the LLM's `BARK` output during FSM transitions.
* [ ] **Pre-Cog Loop:** Script a background asynchronous query in Godot that fires during the `EXECUTING` state, generating "What-If" TOON responses for nearby hazards.
* [ ] **Instant Interrupts:** Update the FSM `INTERRUPTED` state logic to check the unit's local cache for a valid contingency TOON before falling back to `PLANNING` and requesting a fresh inference.

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
│   │   ├── perception.gd         # Handles Radial Scanning and clock-face math
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
Do not progress from one step to the next unless explicitly instructed to do so.
Ensure instructions are relevant to the new editor layout for Godot version 4.6x.
