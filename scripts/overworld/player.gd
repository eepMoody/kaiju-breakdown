extends CharacterBody2D

@export var speed: float = 400.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if direction.length() > 0:
		direction = direction.normalized()

	velocity = direction * speed

	if direction.length() > 0:
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("walk"):
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")

		if direction.x != 0:
			animated_sprite.flip_h = direction.x < 0
	else:
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		else:
			animated_sprite.stop()

	move_and_slide()
