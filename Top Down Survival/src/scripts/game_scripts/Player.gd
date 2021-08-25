extends KinematicBody2D

const MAX_VELOCITY = Vector2(150, 150)
const ACCELERATION = 3000
const FRICTION = 0.8
const LABEL_OFFSET = Vector2(0, -52)
const ATTACK_DAMAGE = 3

var velocity = Vector2.ZERO
var attackable_bodies = []

onready var player_label = $Label
onready var camera = $Camera2D
onready var animated_sprite = $AnimatedSprite
onready var attack_timer = $AttackTimer


func _input(event: InputEvent):
	if is_network_master():
		if Input.is_action_just_pressed("attack"):
			animated_sprite.play("attack")
			attack_timer.start()
			
		if Input.is_action_just_released("attack"):
			animated_sprite.play("idle")
			attack_timer.stop()


func _ready():
	player_label.set_as_toplevel(true)
	set_player_label()


func _physics_process(delta: float):
	if is_network_master():
		camera.current = true
		
		velocity = get_velocity(velocity)
		velocity = move_and_slide(velocity)
		
		look_at(get_global_mouse_position())
		update_label_position()
		
		rpc_unreliable_id(1, "update_player", global_transform, animated_sprite.animation)
		

remote func remote_update(transform: Transform2D, current_animation: String):
	if not is_network_master():
		global_transform = transform
		update_label_position()
		
		animated_sprite.play(current_animation)

func get_velocity(current_velocity: Vector2):
	var new_velocity = current_velocity
	var input_vector = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()
	var accel = input_vector * ACCELERATION * get_physics_process_delta_time()
	
	# Accelerate
	new_velocity += accel
	
	# Limit velocity to maximum velocity
	if new_velocity.x > 0:
		new_velocity.x = min(new_velocity.x, MAX_VELOCITY.x)
	else:
		new_velocity.x = max(new_velocity.x, -MAX_VELOCITY.x)
		
	if new_velocity.y > 0:
		new_velocity.y = min(new_velocity.y, MAX_VELOCITY.y)
	else:
		new_velocity.y = max(new_velocity.y, -MAX_VELOCITY.y)
	
	new_velocity *= FRICTION  # Apply friction
	
	return new_velocity
	
	
func set_player_label():
	player_label.text = Network.players[int(name)]["player_name"]
	
	
func update_label_position():
	var pos_relative = LABEL_OFFSET - player_label.rect_size / 2
	player_label.rect_position = pos_relative + position


func _on_AttackArea_body_entered(body: Node2D):
	if body.is_in_group("Attackable"):
		attackable_bodies.append(body)


func _on_AttackArea_body_exited(body: Node2D):
	if body.is_in_group("Attackable"):
		attackable_bodies.erase(body)


func _on_AttackTimer_timeout():
	for body in attackable_bodies:
		body.request_damage(ATTACK_DAMAGE)
