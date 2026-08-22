class_name BusMixer
extends RefCounted

## Volume sliders, mute, solo, and the buses underneath them.
##
# size-exempt: an options screen needs all of this — a slider that is decibels,
# a mute that keeps the volume, a solo that can be undone, and settings that
# survive a restart. Dropping any one of them leaves a mixer that loses what the
# player chose. The parts are small; there are five of them.
##
## `AudioServer` is a global mixer with a flat list of buses, addressed by index
## — and the indices move whenever a bus is added or removed. Wrapping it is
## worth doing for that reason alone, and for three others that every options
## screen runs into:
##
##   * **Volume is decibels, not a fraction.** A slider at 0.5 is not half as
##     loud; setting `volume_db = 0.5` is barely quieter than full. The
##     conversion is logarithmic, and getting it wrong gives a slider where all
##     the useful range is in the last centimetre.
##   * **Mute is not volume zero.** A muted bus remembers what its volume was.
##     Implementing mute by writing -80 dB loses the setting the player chose,
##     and unmuting has to guess.
##   * **Solo is mute for everyone else.** Which means undoing it has to restore
##     whatever was muted before — not unmute everything.

## Below this, a bus is silent. -60 dB is a thousandth of the amplitude.
const SILENCE_DB := -60.0

var _known: Array[StringName] = []
var _soloed: StringName = &""
var _mute_memory := {}


## A slider value (0..1) as decibels — logarithmic, because hearing is. Halfway
## along should sound like about half as loud, which is -12 dB rather than -6.
static func slider_to_db(value: float) -> float:
	var level := clampf(value, 0.0, 1.0)
	if level <= 0.0:
		return SILENCE_DB
	return maxf(linear_to_db(level * level), SILENCE_DB)


## And back, so a saved decibel value can put the slider where the player left it.
static func db_to_slider(db: float) -> float:
	if db <= SILENCE_DB:
		return 0.0
	return clampf(sqrt(db_to_linear(db)), 0.0, 1.0)


## Find a bus by name, creating it if it is not there.
##
## Names, never indices: adding a bus shifts every index after it, and code that
## remembers "bus 3" starts writing to the wrong one.
func ensure_bus(name: StringName, send: StringName = &"Master") -> int:
	var index := AudioServer.get_bus_index(name)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, send)
	if not _known.has(name):
		_known.append(name)
	return index


func has_bus(name: StringName) -> bool:
	return AudioServer.get_bus_index(name) != -1


## Set a bus's volume from a 0..1 slider value.
func set_level(name: StringName, value: float) -> bool:
	var index := AudioServer.get_bus_index(name)
	if index == -1:
		return false
	AudioServer.set_bus_volume_db(index, slider_to_db(value))
	return true


## Where the slider should sit for this bus.
func level_of(name: StringName) -> float:
	var index := AudioServer.get_bus_index(name)
	if index == -1:
		return 0.0
	return db_to_slider(AudioServer.get_bus_volume_db(index))


## Mute or unmute, without touching the volume.
func set_muted(name: StringName, muted: bool) -> bool:
	var index := AudioServer.get_bus_index(name)
	if index == -1:
		return false
	AudioServer.set_bus_mute(index, muted)
	return true


func is_muted(name: StringName) -> bool:
	var index := AudioServer.get_bus_index(name)
	return index != -1 and AudioServer.is_bus_mute(index)


## Solo one bus: everything else is muted until `clear_solo()`.
##
## The mute states from before are remembered, so clearing the solo puts back
## what the player had rather than unmuting everything.
func solo(name: StringName) -> bool:
	if not has_bus(name):
		return false
	if _soloed == &"":
		_mute_memory.clear()
		for bus in _known:
			_mute_memory[bus] = is_muted(bus)
	_soloed = name
	for bus in _known:
		set_muted(bus, bus != name)
	return true


func clear_solo() -> void:
	if _soloed == &"":
		return
	for bus in _known:
		set_muted(bus, bool(_mute_memory.get(bus, false)))
	_soloed = &""
	_mute_memory.clear()


func soloed() -> StringName:
	return _soloed


## Add an effect to a bus — a reverb, a filter, a limiter.
func add_effect(name: StringName, effect: AudioEffect) -> bool:
	var index := AudioServer.get_bus_index(name)
	if index == -1 or effect == null:
		return false
	AudioServer.add_bus_effect(index, effect)
	return true


## The mixer as plain data, for a settings file.
func to_dictionary() -> Dictionary:
	var out := {}
	for bus in _known:
		out[String(bus)] = {"level": level_of(bus), "muted": is_muted(bus)}
	return out


## Restore levels and mutes. Buses in the file that no longer exist are skipped.
func load_from(data: Dictionary) -> int:
	var restored := 0
	for name in data:
		var bus := StringName(name)
		if not has_bus(bus):
			continue
		var entry = data[name]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		set_level(bus, float(entry.get("level", 1.0)))
		set_muted(bus, bool(entry.get("muted", false)))
		restored += 1
	return restored


func buses() -> Array[StringName]:
	return _known.duplicate()


## Remove every bus this mixer created, newest first.
##
## Newest first because removing a bus shifts the indices of the ones after it —
## the same reason nothing here stores an index.
func remove_all() -> void:
	for i in range(_known.size() - 1, -1, -1):
		var index := AudioServer.get_bus_index(_known[i])
		if index > 0:
			AudioServer.remove_bus(index)
	_known.clear()
	_mute_memory.clear()
	_soloed = &""
