extends Node

const PlayerControllerClass:=preload("res://scripts/gameplay/player_controller.gd")

var passed:=0
var failures: Array[String]=[]

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		passed+=1
	else:
		failures.append(message)
		push_error("PLAYER PRESENTATION TEST FAILURE: "+message)

func _run() -> void:
	var player:=PlayerControllerClass.new()
	player.position=Vector2(270,790)
	player.combat_bounds=Rect2(24,395,492,450)
	add_child(player)
	await get_tree().process_frame
	var initial_position:=player.position
	var initial_bounds:=player.combat_bounds
	var initial_health:=player.health
	var initial_dash_charges:=player.dash_charges
	var initial_shield:=player.shield_hits
	var unarmed:=player.presentation_snapshot()
	_check(not bool(unarmed.aether_awakened),"Hero must start visibly unarmed before Aether awakens")
	_check(not bool(unarmed.visible_weapon),"Opening presentation cannot expose a physical weapon")
	_check(not bool(unarmed.muzzle_fire),"Opening presentation cannot emit muzzle fire")
	_check(bool(unarmed.hero_asset_loaded)==ResourceLoader.exists(PlayerControllerClass.HERO_TEXTURE_PATH),"Hero asset branch must match the stable optional resource path")
	player.queue_redraw()
	await get_tree().process_frame
	player.set_aether_awakened(true)
	var awakened:=player.presentation_snapshot()
	_check(bool(awakened.aether_awakened),"Aether setter must expose the awakened hand-spark state")
	_check(not bool(awakened.visible_weapon),"Awakened Aether remains hand-cast without a physical weapon")
	_check(not bool(awakened.muzzle_fire),"Awakened Aether spark cannot become a muzzle flash")
	_check(player.position.is_equal_approx(initial_position),"Presentation transition cannot move the player")
	_check(player.combat_bounds==initial_bounds,"Presentation transition cannot change combat bounds")
	_check(is_equal_approx(player.health,initial_health),"Presentation transition cannot change health")
	_check(player.dash_charges==initial_dash_charges,"Presentation transition cannot change Dash charges")
	_check(player.shield_hits==initial_shield,"Presentation transition cannot change shield state")
	player.set_aether_awakened(true)
	_check(bool(player.presentation_snapshot().aether_awakened),"Aether setter must be idempotent")
	player.set_aether_awakened(false)
	_check(not bool(player.presentation_snapshot().aether_awakened),"Aether presentation must support an explicit unarmed reset")
	_check(player.request_dash(Vector2.UP),"Existing Dash API must remain operational after presentation changes")
	_check(player.dash_time>0.0 and player.invulnerability>0.0,"Dash timing and invulnerability must remain intact")
	player.add_shield_hit()
	_check(player.shield_hits==initial_shield+1,"Existing shield API must remain operational")
	player.queue_redraw()
	await get_tree().process_frame
	player.queue_free()
	await get_tree().process_frame
	print("INFINIDIVE PLAYER PRESENTATION TESTS: %d passed, %d failed"%[passed,failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
