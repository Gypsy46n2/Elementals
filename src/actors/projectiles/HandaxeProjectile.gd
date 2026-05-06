extends BaseProjectile

@onready var model_node: Node3D = $Model

@export var rotation_speed: float = -2.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if not _is_stuck and model_node:
		# Spin the model around its local X axis (which is the lateral axis if it's facing forward)
		# Or Z axis depending on orientation. 
		# Given the default orientation in initialize(), the projectile faces +Z (FORWARD).
		# Spinning around X will make it "flip" forward.
		model_node.rotate_x(rotation_speed * delta)
