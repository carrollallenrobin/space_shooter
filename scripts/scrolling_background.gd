@tool
class_name ScrollingBackground
extends Node2D
## Reusable infinite vertical scrolling background.
## Drop scenes/scrolling_background.tscn into any scene and swap `texture`.
## Tiles are scaled to cover the viewport width and recycled as they scroll.

## Background image. Change this to reuse the scene with another asset.
@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild()

## Scroll speed in pixels per second (positive = image moves down, ship appears to fly up).
@export var scroll_speed: float = 60.0

## Rotate the image 90° (for landscape images used on a portrait screen).
@export var rotate_90: bool = false:
	set(value):
		rotate_90 = value
		_rebuild()

## Mirror every other tile so non-seamless images join without a visible seam.
## Turn off if the texture already tiles seamlessly.
@export var mirror_alternate: bool = true:
	set(value):
		mirror_alternate = value
		_rebuild()

## Scroll in the editor preview too.
@export var preview_in_editor: bool = false

var _tiles: Array[Sprite2D] = []
var _tile_height: float = 0.0
var _period: float = 0.0
var _offset: float = 0.0
var _view_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_rebuild)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	if _period <= 0.0:
		return
	_offset = fposmod(_offset + scroll_speed * delta, _period)
	_layout_tiles()


func _get_view_size() -> Vector2:
	if Engine.is_editor_hint():
		return Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width", 720),
			ProjectSettings.get_setting("display/window/size/viewport_height", 1280))
	return get_viewport_rect().size


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for t in _tiles:
		t.queue_free()
	_tiles.clear()
	_period = 0.0
	if texture == null:
		return

	_view_size = _get_view_size()
	var tex_size := texture.get_size()
	# On-screen size of one unscaled tile (swapped when rotated).
	var raw := Vector2(tex_size.y, tex_size.x) if rotate_90 else tex_size
	var tile_scale := _view_size.x / raw.x  # cover full width
	# 1px overlap hides sub-pixel gaps between tiles.
	_tile_height = raw.y * tile_scale - 1.0

	var tiles_per_period := 2 if mirror_alternate else 1
	_period = _tile_height * tiles_per_period
	var count := int(ceil((_view_size.y + _period) / _tile_height)) + 1
	if mirror_alternate and count % 2 == 1:
		count += 1

	for i in count:
		var s := Sprite2D.new()
		s.texture = texture
		s.centered = true
		s.scale = Vector2(tile_scale, tile_scale)
		s.rotation = PI / 2.0 if rotate_90 else 0.0
		if mirror_alternate and i % 2 == 1:
			# Flip along the screen's vertical axis (texture X when rotated).
			if rotate_90:
				s.flip_h = true
			else:
				s.flip_v = true
		add_child(s, false, Node.INTERNAL_MODE_FRONT)
		_tiles.append(s)
	_layout_tiles()


func _layout_tiles() -> void:
	var cx := _view_size.x / 2.0
	for i in _tiles.size():
		var top := _offset - _period + i * _tile_height
		_tiles[i].position = Vector2(cx, top + _tile_height / 2.0)
