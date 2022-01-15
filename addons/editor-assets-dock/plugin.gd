tool
extends EditorPlugin

# Node references
var bottom_panel : Control
var asset_panel : Control

# Scene references
const PanelWrapper : GDScript = preload("res://addons/editor-assets-dock/PluginPanelWrapper.gd")
const asset_panel_scene : PackedScene = preload("res://addons/editor-assets-dock/AssetPanel.tscn")

func _enter_tree() -> void:
	bottom_panel = PanelWrapper.new()
	asset_panel = asset_panel_scene.instance()
	bottom_panel.add_child(asset_panel)
	add_control_to_bottom_panel(bottom_panel, "Assets")

	asset_panel.connect("edit_resource", self, "_on_edit_resource_requested")

	get_editor_interface().get_resource_filesystem().connect("filesystem_changed", self, "_on_filesystem_changed")
	_on_filesystem_changed()

func _exit_tree() -> void:
	asset_panel.disconnect("edit_resource", self, "_on_edit_resource_requested")

	remove_control_from_bottom_panel(bottom_panel)
	asset_panel.queue_free()
	bottom_panel.queue_free()

	get_editor_interface().get_resource_filesystem().disconnect("filesystem_changed", self, "_on_filesystem_changed")

# Handlers
func _on_filesystem_changed() -> void:
	var editor_fs = get_editor_interface().get_resource_filesystem()
	var root_dir = editor_fs.get_filesystem()

	var all_resources := []
	_traverse_project_dir(root_dir, all_resources)

	all_resources.sort_custom(self, "_sort_resources")

	asset_panel.resources = all_resources

func _on_edit_resource_requested(resource_path: String) -> void:
	var resource = ResourceLoader.load(resource_path)
	if (resource):
		get_editor_interface().edit_resource(resource)

# Helpers
func _traverse_project_dir(dir: EditorFileSystemDirectory, resources: Array) -> void:
	var resource_previews = get_editor_interface().get_resource_previewer()

	var dir_path = dir.get_path()
	# Ignore our own files <_<
	if (dir_path.begins_with("res://addons/editor-assets-dock")):
		return

	# Iterate directory's resources and gather their data.
	for fi in dir.get_file_count():
		var imported = dir.get_file_import_is_valid(fi)
		if (!imported):
			continue

		var file_type = dir.get_file_type(fi)
		if (ClassDB.is_parent_class(file_type, "Script")):
			continue

		var file_path = dir.get_file_path(fi)
		var resource_data := {
			"path": file_path,
			"type": file_type,
			"common_type": _get_common_type(file_type),
			"preview": null,
		}
		resources.append(resource_data)

		resource_previews.queue_resource_preview(file_path, self, "_update_resource_preview", resource_data)

	# Check subdirectories as well.
	for di in dir.get_subdir_count():
		var subdir = dir.get_subdir(di)
		_traverse_project_dir(subdir, resources)

func _sort_resources(res_a: Dictionary, res_b: Dictionary) -> bool:
	return (res_a.path < res_b.path)

func _get_common_type(resource_type: String) -> String:
	if (ClassDB.is_parent_class(resource_type, "Texture")):
		return "Texture"

	if (ClassDB.is_parent_class(resource_type, "Material")):
		return "Material"

	if (ClassDB.is_parent_class(resource_type, "StyleBox")):
		return "StyleBox"

	return resource_type

func _update_resource_preview(resource_path: String, preview: Texture, thumbnail_preview: Texture, resource_data: Dictionary) -> void:
	resource_data.preview = preview
	asset_panel.update_preview(resource_path, preview)
