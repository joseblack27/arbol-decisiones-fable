extends ProgressBar
class_name LoadingBar

@export var next_scene_path: String = "res://scenes/ui/main/MainOs.tscn"
@export var show_text: bool = false
var progress: Array[float] = []

@onready var text: Label = $Text

func _ready():
	ResourceLoader.load_threaded_request(next_scene_path)
	text.visible = show_text

func _process(_delta):
	var status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var pct = progress[0] * 100
			value = pct
			text.text = str(value , "%")
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene = ResourceLoader.load_threaded_get(next_scene_path)
			value = 100
			text.text = "100%"
			#get_tree().change_scene_to_packed(scene)
