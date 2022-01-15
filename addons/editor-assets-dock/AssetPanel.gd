tool
extends VBoxContainer

# Public properties
var resources : Array = [] setget set_resources

# Private properties
var _item_map : Dictionary = {}
var _type_list : Array = []

var _name_filter : String = ""
var _type_filter : String = ""
var _include_addons_filter : bool = false
var _group_similar_filter : bool = false

const ADDONS_PATH : String = "res://addons"

# Node references
onready var name_filter_edit : LineEdit = $NameFilter/FilterValue
onready var include_addons_check : CheckBox = $Split/Toolbar/AddonsFilter/FilterCheck
onready var group_similar_check : CheckBox = $Split/Toolbar/SimilarFilter/FilterCheck
onready var group_tabs : Tabs = $Split/Content/GroupTabs

onready var scroll_container : ScrollContainer = $Split/Content/ScrollContainer
onready var asset_list : GridContainer = $Split/Content/ScrollContainer/AssetList

# Scene references
const asset_item_scene : PackedScene = preload("res://addons/editor-assets-dock/AssetItem.tscn")

signal edit_resource(resource_path)

func _ready() -> void:
	_update_theme()
	_update_tabs()
	_update_list()

	name_filter_edit.connect("text_changed", self, "_on_name_filter_changed")
	include_addons_check.connect("toggled", self, "_on_include_addons_toggled")
	group_similar_check.connect("toggled", self, "_on_group_similar_toggled")
	group_tabs.connect("tab_changed", self, "_on_group_tab_changed")
	scroll_container.connect("resized", self, "_on_asset_list_resized")

# Properties
func set_resources(value: Array) -> void:
	resources = value
	_update_tabs()
	_update_list()

# Public methods
func update_preview(path: String, preview: Texture) -> void:
	if (!_item_map.has(path)):
		return

	_item_map[path].resource_preview = preview

# Helpers
func _update_theme() -> void:
	var panel_bg = get_stylebox("bg", "ItemList").duplicate()
	scroll_container.add_stylebox_override("bg", panel_bg)

func _update_tabs() -> void:
	# Clear the tab bar.
	while (group_tabs.get_tab_count() > 0):
		group_tabs.remove_tab(0)

	# Collect available resource types.
	_type_list = []
	for resource_data in resources:
		var ref_type = resource_data.type
		if (_group_similar_filter):
			ref_type = resource_data.common_type

		var existing_type := _find_type(ref_type)
		if (existing_type.empty()):
			_type_list.append({
				"name": ref_type,
				"count": 1,
			})
		else:
			existing_type.count += 1

	# Sort types alphabetically.
	_type_list.sort_custom(self, "_sort_types")

	# Create tabs for every type.
	for type_data in _type_list:
		var tab_name = "%s (%d)" % [ type_data.name, type_data.count ]
		var tab_icon = get_icon(type_data.name, "EditorIcons")
		group_tabs.add_tab(tab_name, tab_icon)

	# Create a common tab and put it in front.
	_type_list.push_front({
		"name": "",
		"count": resources.size(),
	})
	group_tabs.add_tab("All Assets (%d)" % resources.size())
	group_tabs.move_tab(group_tabs.get_tab_count() - 1, 0)

	# Unset the type filter if the type does not exist anymore.
	if (!_type_filter.empty()):
		var filtered_type := _find_type(_type_filter)
		if (filtered_type.empty()):
			_type_filter = ""

	# Make sure that for existing types the selected tab persists.
	if (_type_filter.empty()):
		group_tabs.current_tab = 0
	else:
		group_tabs.current_tab = _find_type_index(_type_filter)

	_update_tab_counts()

func _update_tab_counts() -> void:
	var i := 0
	for type_data in _type_list:
		var count = 0

		for resource_data in resources:
			if (i > 0):
				if (_group_similar_filter && resource_data.common_type != type_data.name):
					continue
				if (!_group_similar_filter && resource_data.type != type_data.name):
					continue

			var file_name = resource_data.path.get_file()
			if (!_name_filter.empty() && file_name.findn(_name_filter) < 0):
				continue

			if (!_include_addons_filter && resource_data.path.begins_with(ADDONS_PATH)):
				continue

			count += 1

		if (i == 0):
			group_tabs.set_tab_title(i, "All Assets (%d)" % [ count ])
		else:
			group_tabs.set_tab_title(i, "%s (%d)" % [ type_data.name, count ])

		i += 1

func _find_type(type_name: String) -> Dictionary:
	var existing_type := {}

	for type_data in _type_list:
		if (type_data.name == type_name):
			existing_type = type_data
			break

	return existing_type

func _find_type_index(type_name: String) -> int:
	var i := 0
	for type_data in _type_list:
		if (type_data.name == type_name):
			return i
		i += 1

	return 0

func _sort_types(type_a: Dictionary, type_b: Dictionary) -> bool:
	return type_a.name < type_b.name

func _update_list() -> void:
	if (!is_inside_tree()):
		return

	_item_map = {}
	for asset_item in asset_list.get_children():
		asset_item.disconnect("edit_resource", self, "_on_edit_resource")
		asset_list.remove_child(asset_item)
		asset_item.queue_free()

	for resource_data in resources:
		var file_name = resource_data.path.get_file()
		if (!_name_filter.empty() && file_name.findn(_name_filter) < 0):
			continue

		if (!_type_filter.empty()):
			if (_group_similar_filter && resource_data.common_type != _type_filter):
				continue
			if (!_group_similar_filter && resource_data.type != _type_filter):
				continue

		if (!_include_addons_filter && resource_data.path.begins_with(ADDONS_PATH)):
			continue

		var asset_item = asset_item_scene.instance()
		asset_item.resource_path = resource_data.path
		asset_item.resource_type = resource_data.type
		asset_item.resource_preview = resource_data.preview

		asset_list.add_child(asset_item)
		_item_map[resource_data.path] = asset_item

		asset_item.connect("edit_resource", self, "_on_edit_resource")

# Handlers
func _on_name_filter_changed(value: String) -> void:
	_name_filter = value
	_update_list()
	_update_tab_counts()

func _on_include_addons_toggled(enabled: bool) -> void:
	_include_addons_filter = enabled
	_update_list()
	_update_tab_counts()

func _on_group_similar_toggled(enabled: bool) -> void:
	_group_similar_filter = enabled
	_update_tabs()
	_update_list()

func _on_group_tab_changed(tab_index: int) -> void:
	if (tab_index == 0):
		# If we selected "All", which is always first, unset the filter.
		_type_filter = ""
	else:
		_type_filter = _type_list[tab_index].name

	_update_list()
	_update_tab_counts()

func _on_edit_resource(resource_path: String) -> void:
	emit_signal("edit_resource", resource_path)

func _on_asset_list_resized() -> void:
	var asset_item = asset_item_scene.instance()
	var item_size = asset_item.rect_min_size
	asset_item.queue_free()
	
	prints(scroll_container.rect_size.x, item_size.x, floor(scroll_container.rect_size.x / item_size.x))
	asset_list.columns = floor(scroll_container.rect_size.x / item_size.x)
