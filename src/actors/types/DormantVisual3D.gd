extends Node3D

## ZZZ visual effect that displays above dormant actors.

@export var bob_amplitude: float = 0.05
@export var bob_speed: float = 2.0
@export var float_height: float = 1.2

var _time: float = 0.0
var _letters: Array[Label3D] = []

func _ready() -> void:
	_setup_zzz_billboard()

func _setup_zzz_billboard() -> void:
	var zzz_text: Array[String] = ["Z", "Z", "Z"]
	var spacing: float = 0.15
	
	for i in range(3):
		var label := Label3D.new()
		label.text = zzz_text[i]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.render_priority = 10
		label.modulate = Color.WHITE
		label.outline_modulate = Color.BLACK
		label.pixel_size = 0.01
		label.font_size = 32
		
		# Position letters horizontally with slight offset
		label.position = Vector3(i * spacing - spacing, 0, 0)
		label.set_meta("phase_offset", float(i) * 0.5)
		
		add_child(label)
		_letters.append(label)
	
	position.y = float_height

func _process(delta: float) -> void:
	_time += delta
	
	# Bob up and down
	position.y = float_height + sin(_time * bob_speed) * bob_amplitude
	
	# Individual letter bobbing
	for i in range(_letters.size()):
		var label: Label3D = _letters[i]
		var phase = _time * bob_speed * 0.8 + label.get_meta("phase_offset")
		label.position.y = sin(phase) * bob_amplitude * 0.5
