extends Node
## Central signal hub for cross-system communication.
## All game systems communicate through here to stay decoupled.
## Usage: EventBus.signal_name.emit(args)

# ── PLAYER ──────────────────────────────────────────────────
signal player_health_changed(current: float, max_health: float)
signal player_died()
signal player_respawned(position: Vector2)

# ── COMBAT ──────────────────────────────────────────────────
signal damage_dealt(target: Node, amount: float, source: Node)
signal damage_received(target: Node, amount: float)
signal entity_died(entity: Node)

# ── ABILITIES ───────────────────────────────────────────────
signal ability_used(entity: Node, ability_type: String)
signal ability_hit(ability_type: String, target: Node)
signal ability_cooldown_started(entity: Node, ability_type: String, duration: float)
signal ability_cooldown_ended(entity: Node, ability_type: String)

# ── INPUT (HUD → Game logic) ─────────────────────────────────
## Emitted by HUD controls; consumed by Player ability container
signal ability_input_basic_attack()
signal ability_input_projectile(direction: Vector2, power: float)
signal ability_input_area_attack(direction: Vector2, power: float)
signal ability_input_charge(direction: Vector2, power: float)
signal movement_input_changed(direction: Vector2)

# ── AIM PREVIEW (UI → World) ─────────────────────────────────
## Emitted while a joystick ability is being dragged
signal ability_aim_updated(ability_type: String, direction: Vector2, power: float)
## Emitted when the joystick is released (ability fires or was cancelled)
signal ability_aim_cleared()
## Emitted when the player explicitly cancels an aimed ability without firing
signal ability_aim_cancelled()

# ── GAME ─────────────────────────────────────────────────────
signal game_paused()
signal game_resumed()
signal scene_change_requested(scene_path: String)
