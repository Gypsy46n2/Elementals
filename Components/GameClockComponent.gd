## Centralized game clock that all actors and components can subscribe to.
## Replaces individual timer nodes with a single shared tick system.
class_name GameClockComponent
extends Node

signal tick_elapsed(delta: float)

var tick_rate: float = 0.1  # 10Hz base tick rate
var _accumulator: float = 0.0

var _callbacks: Array[Dictionary] = []

## Register a callback to be called at the configured tick rate.
## Returns callback ID for later removal.
func register_tick(callback: Callable, custom_interval: float = 0.0) -> int:
	# custom_interval > 0 means use that interval, otherwise use default tick_rate
	var interval: float = custom_interval if custom_interval > 0 else tick_rate
	var id: int = _callbacks.size()
	_callbacks.append({
		"callback": callback,
		"interval": interval,
		"accumulator": 0.0,
		"active": true,
		"id": id
	})
	return id

## Unregister a tick callback by ID
func unregister_tick(id: int) -> void:
	for cb in _callbacks:
		if cb.get("id") == id:
			cb["active"] = false
			return

## Unregister by callback reference (cleanup helper)
func unregister_by_callback(callback: Callable) -> void:
	for cb in _callbacks:
		if cb.get("callback") == callback:
			cb["active"] = false
			return

## Pause/unpause all ticking
var _paused: bool = false
var paused: bool:
	get: return _paused
	set(v): _paused = v

func _physics_process(delta: float) -> void:
	if _paused:
		return
	
	_accumulator += delta
	if _accumulator >= tick_rate:
		tick_elapsed.emit(tick_rate)
		
		# Reset and process sub-tick callbacks
		_accumulator = 0.0
		
		for cb in _callbacks:
			if not cb.get("active", true):
				continue
			
			var acc: float = cb.get("accumulator", 0.0) + tick_rate
			var interval: float = cb.get("interval", tick_rate)
			
			if acc >= interval:
				acc = 0.0
				var callback: Callable = cb.get("callback")
				if callback.is_valid():
					callback.call()
			
			cb["accumulator"] = acc
