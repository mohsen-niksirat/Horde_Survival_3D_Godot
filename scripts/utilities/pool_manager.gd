extends Node
## Generic object pooling for high-frequency nodes (enemies, projectiles, pickups, VFX).
## Pools are created per scene path. Acquire/release never instantiates/destroys
## in steady state — nodes are recycled.

var _pools: Dictionary = {}
var _release_queue: Array = []
var _pending_release: Dictionary = {}  # instance_id -> true (dedupe)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# Deferred release: safe during physics callbacks
	if _release_queue.is_empty():
		return
	var queue := _release_queue
	_release_queue = []
	_pending_release.clear()
	for item in queue:
		_release_now(item[0], item[1])

## Create (or get) a pool for a scene with an initial prewarm size.
func create_pool(scene_path: String, prewarm: int = 0) -> void:
	if _pools.has(scene_path):
		# Pool exists — top up free list to prewarm target if short
		var pool: Dictionary = _pools[scene_path]
		var deficit := prewarm - int(pool["free"].size())
		for i in range(maxi(deficit, 0)):
			var node := _instantiate(pool)
			node.visible = false
			pool["free"].append(node)
		return
	var pool := {
		"scene": load(scene_path),
		"free": [],
		"active_count": 0,
		"total_created": 0,
	}
	_pools[scene_path] = pool
	for i in range(prewarm):
		var node := _instantiate(pool)
		node.visible = false
		pool["free"].append(node)

func _instantiate(pool: Dictionary) -> Node:
	var node: Node = pool["scene"].instantiate()
	pool["total_created"] += 1
	return node

## Acquire an instance. Caller must add it to the tree.
func acquire(scene_path: String) -> Node:
	if not _pools.has(scene_path):
		create_pool(scene_path)
	var pool: Dictionary = _pools[scene_path]
	var node: Node
	if pool["free"].is_empty():
		node = _instantiate(pool)
	else:
		node = pool["free"].pop_back()
	# Released nodes were hidden — restore visibility for their new life.
	node.visible = true
	pool["active_count"] += 1
	return node

## Release an instance back to its pool. Deferred: safe in physics callbacks.
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _pending_release.has(node.get_instance_id()):
		return  # already queued (double-release guard)
	var scene_path: String = node.get_meta("pool_scene", "")
	if scene_path == "" or not _pools.has(scene_path):
		node.queue_free()
		return
	_pending_release[node.get_instance_id()] = true
	_release_queue.append([scene_path, node])

func _release_now(scene_path: String, node: Node) -> void:
	if not _pools.has(scene_path):
		return
	if not is_instance_valid(node):
		# Node was freed elsewhere (e.g. queue_free) while queued for
		# release — drop it instead of corrupting the pool.
		return
	var pool: Dictionary = _pools[scene_path]
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.visible = false
	pool["free"].append(node)
	pool["active_count"] -= 1

## Mark a node as poolable under a scene path (call right after acquire).
func tag(node: Node, scene_path: String) -> void:
	node.set_meta("pool_scene", scene_path)

func get_pool_stats(scene_path: String) -> Dictionary:
	if not _pools.has(scene_path):
		return {}
	var pool: Dictionary = _pools[scene_path]
	return {
		"free": pool["free"].size(),
		"active": pool["active_count"],
		"created": pool["total_created"],
	}

func get_all_stats() -> Dictionary:
	var out := {}
	for key in _pools:
		out[key] = get_pool_stats(key)
	return out

func clear_all() -> void:
	for key in _pools:
		var pool: Dictionary = _pools[key]
		for node in pool["free"]:
			if is_instance_valid(node):
				node.queue_free()
	_pools.clear()
