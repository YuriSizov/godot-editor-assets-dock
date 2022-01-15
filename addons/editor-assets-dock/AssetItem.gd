tool
extends PanelContainer

# Public properties
var resource_path : String = "" setget set_resource_path
var resource_type : String = "" setget set_resource_type
var resource_preview : Texture setget set_resource_preview

# Node references
onready var resource_icon : TextureRect = $Layout/ResourceName/ResourceTypeIcon
onready var resource_title : Label = $Layout/ResourceName/ResourceLabel
onready var resource_texture : TextureRect = $Layout/ResourcePreview

signal edit_resource(resource_path)

func _ready() -> void:
	_update_theme()
	_update_item()
	
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")

func _gui_input(event: InputEvent) -> void:
	var mb = event as InputEventMouseButton
	if (mb && mb.pressed && mb.doubleclick):
		emit_signal("edit_resource", resource_path)

func get_drag_data(position: Vector2):
	var drag_data := {}
	drag_data["type"] = "files"
	drag_data["files"] = [ resource_path ]
	drag_data["from"] = self
	
	var drag_preview := HBoxContainer.new()
	
	var drag_icon := TextureRect.new()
	drag_icon.texture = get_icon(resource_type, "EditorIcons")
	drag_preview.add_child(drag_icon)
	
	var drag_label := Label.new()
	drag_label.text = resource_path.get_file()
	drag_preview.add_child(drag_label)
	
	set_drag_preview(drag_preview)
	
	return drag_data

# Properties
func set_resource_path(value: String) -> void:
	resource_path = value
	_update_item()

func set_resource_type(value: String) -> void:
	resource_type = value
	_update_item()

func set_resource_preview(value: Texture) -> void:
	resource_preview = value
	_update_item()

# Helpers
func _update_theme() -> void:
	if (!is_inside_tree()):
		return
	
	var default_style = get_stylebox("selected", "ItemList").duplicate()
	if (default_style is StyleBoxFlat):
		default_style.bg_color.a = 0.0
	
	add_stylebox_override("panel", default_style)

func _update_item() -> void:
	if (!is_inside_tree()):
		return
	
	hint_tooltip = resource_path
	if (!resource_path.empty()):
		resource_title.text = resource_path.get_file()
	
	resource_icon.texture = get_icon(resource_type, "EditorIcons")
	resource_texture.texture = resource_preview

# Handlers
func _on_mouse_entered() -> void:
	add_stylebox_override("panel", get_stylebox("selected", "ItemList"))

func _on_mouse_exited() -> void:
	var default_style = get_stylebox("selected", "ItemList").duplicate()
	if (default_style is StyleBoxFlat):
		default_style.bg_color.a = 0.0
	
	add_stylebox_override("panel", default_style)
