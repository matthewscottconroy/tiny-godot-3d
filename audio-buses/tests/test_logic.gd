extends Node

# Drives the real BusMixer from scripts/bus_mixer.gd against Godot's real
# AudioServer.
#
# The AudioServer is global state, like the InputMap: the buses here are
# prefixed so they cannot collide with a project's own, and removed again at the
# end. A suite that leaves buses behind has changed the mixer for whatever runs
# next.

var _pass := 0
var _fail := 0
var _mixer := BusMixer.new()

const MUSIC := &"TestMusic"
const EFFECTS := &"TestEffects"
const VOICE := &"TestVoice"

func _ready() -> void:
	test_the_slider_is_logarithmic()
	test_the_slider_round_trips()
	test_creating_a_bus()
	test_creating_it_twice()
	test_levels_reach_the_server()
	test_mute_is_not_volume()
	test_solo_mutes_everyone_else()
	test_clearing_a_solo_restores_what_was_muted()
	test_effects_can_be_added()
	test_unknown_buses_are_refused()
	test_saving_and_restoring()
	test_removing_everything()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	_mixer.remove_all()
	var summary := "[audio-buses] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

func _build() -> void:
	_mixer.ensure_bus(MUSIC)
	_mixer.ensure_bus(EFFECTS)
	_mixer.ensure_bus(VOICE)

func test_the_slider_is_logarithmic() -> void:
	print("the slider")
	expect(is_equal_approx(BusMixer.slider_to_db(1.0), 0.0), "full is 0 dB, which is unchanged")
	expect(is_equal_approx(BusMixer.slider_to_db(0.0), BusMixer.SILENCE_DB), "zero is silence")
	# Setting volume_db from the slider directly is the bug this exists for: at
	# 0.5 it would be 0.5 dB, which is very nearly full volume.
	var half := BusMixer.slider_to_db(0.5)
	expect(half < -10.0 and half > -14.0, "half way along is about -12 dB, not -0.5")
	expect(BusMixer.slider_to_db(0.25) < half, "and the curve keeps falling")

func test_the_slider_round_trips() -> void:
	print("round trip")
	for value in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var back := BusMixer.db_to_slider(BusMixer.slider_to_db(value))
		expect(absf(back - value) < 0.01, "a slider at %.2f comes back as itself" % value)

func test_creating_a_bus() -> void:
	print("creating")
	var index := _mixer.ensure_bus(MUSIC)
	expect(index > 0, "a new bus is created past the master")
	expect(AudioServer.get_bus_name(index) == MUSIC, "with the name it was given")
	expect(_mixer.has_bus(MUSIC), "and the mixer knows about it")

func test_creating_it_twice() -> void:
	print("idempotent")
	var first := _mixer.ensure_bus(EFFECTS)
	var count := AudioServer.bus_count
	var second := _mixer.ensure_bus(EFFECTS)
	expect(first == second, "asking twice returns the same bus")
	expect(AudioServer.bus_count == count, "rather than adding a second one with the same name")

func test_levels_reach_the_server() -> void:
	print("volume")
	_build()
	_mixer.set_level(MUSIC, 0.5)
	var index := AudioServer.get_bus_index(MUSIC)
	expect(is_equal_approx(AudioServer.get_bus_volume_db(index), BusMixer.slider_to_db(0.5)),
		"setting a level writes decibels to the real bus")
	expect(absf(_mixer.level_of(MUSIC) - 0.5) < 0.01, "and reading it back gives the slider position")

func test_mute_is_not_volume() -> void:
	print("mute")
	_build()
	_mixer.set_level(VOICE, 0.7)
	_mixer.set_muted(VOICE, true)
	expect(_mixer.is_muted(VOICE), "the bus is muted")
	# Muting by writing -80 dB loses the level the player chose, and unmuting
	# then has to guess what it was.
	expect(absf(_mixer.level_of(VOICE) - 0.7) < 0.01, "and its volume is untouched")
	_mixer.set_muted(VOICE, false)
	expect(not _mixer.is_muted(VOICE), "unmuting works")
	expect(absf(_mixer.level_of(VOICE) - 0.7) < 0.01, "and the level is still what it was")

func test_solo_mutes_everyone_else() -> void:
	print("solo")
	_build()
	_mixer.set_muted(MUSIC, false)
	_mixer.set_muted(EFFECTS, false)
	_mixer.set_muted(VOICE, false)
	expect(_mixer.solo(EFFECTS), "soloing succeeds")
	expect(not _mixer.is_muted(EFFECTS), "the soloed bus plays")
	expect(_mixer.is_muted(MUSIC) and _mixer.is_muted(VOICE), "and everything else is muted")
	expect(_mixer.soloed() == EFFECTS, "the mixer reports which bus is soloed")

func test_clearing_a_solo_restores_what_was_muted() -> void:
	print("un-soloing")
	_build()
	_mixer.clear_solo()
	# The state before the solo: music muted by the player, the rest not.
	_mixer.set_muted(MUSIC, true)
	_mixer.set_muted(EFFECTS, false)
	_mixer.set_muted(VOICE, false)
	_mixer.solo(VOICE)
	_mixer.clear_solo()
	expect(_mixer.is_muted(MUSIC), "a bus the player had muted is still muted afterwards")
	expect(not _mixer.is_muted(EFFECTS), "and one they had not is not")
	expect(_mixer.soloed() == &"", "with nothing soloed any more")

	# A bus that only appeared after the solo started has no remembered state.
	# Defaulting that to "was muted" leaves a bus silent that nobody muted.
	_mixer.solo(EFFECTS)
	_mixer.ensure_bus(&"TestLate")
	_mixer.clear_solo()
	expect(not _mixer.is_muted(&"TestLate"),
		"and a bus created during a solo comes out of it unmuted")

func test_effects_can_be_added() -> void:
	print("effects")
	_build()
	var reverb := AudioEffectReverb.new()
	expect(_mixer.add_effect(VOICE, reverb), "an effect can be added to a bus")
	var index := AudioServer.get_bus_index(VOICE)
	expect(AudioServer.get_bus_effect_count(index) >= 1, "and the server has it")
	expect(not _mixer.add_effect(&"NoSuchBus", AudioEffectReverb.new()),
		"while a bus that does not exist is refused")
	expect(not _mixer.add_effect(VOICE, null), "and so is an effect that is not there")

func test_unknown_buses_are_refused() -> void:
	print("unknown buses")
	expect(not _mixer.set_level(&"NoSuchBus", 0.5), "setting a level on nothing fails quietly")
	expect(is_zero_approx(_mixer.level_of(&"NoSuchBus")), "reading one gives zero")
	expect(not _mixer.set_muted(&"NoSuchBus", true), "and muting it does nothing")
	expect(not _mixer.is_muted(&"NoSuchBus"), "so it is not muted either")
	var was_muted := [_mixer.is_muted(MUSIC), _mixer.is_muted(EFFECTS)]
	expect(not _mixer.solo(&"NoSuchBus"), "and soloing nothing is refused rather than silencing everything")
	expect(was_muted == [_mixer.is_muted(MUSIC), _mixer.is_muted(EFFECTS)],
		"leaving every real bus exactly as it was")

	# The other half of a boolean return: it has to say yes when it worked, or a
	# caller that checks it treats every success as a failure.
	_build()
	expect(_mixer.set_level(MUSIC, 0.5), "setting a level on a real bus reports success")
	expect(_mixer.set_muted(MUSIC, true), "and so does muting one")
	_mixer.set_muted(MUSIC, false)

func test_saving_and_restoring() -> void:
	print("persistence")
	_build()
	_mixer.clear_solo()
	_mixer.set_level(MUSIC, 0.3)
	_mixer.set_muted(EFFECTS, true)
	var saved := _mixer.to_dictionary()

	_mixer.set_level(MUSIC, 1.0)
	_mixer.set_muted(EFFECTS, false)
	expect(_mixer.load_from(saved) == saved.size(), "every saved bus is restored")
	expect(absf(_mixer.level_of(MUSIC) - 0.3) < 0.01, "with its level")
	expect(_mixer.is_muted(EFFECTS), "and its mute")

	var stale := {"BusFromAnOlderBuild": {"level": 0.5, "muted": false}}
	expect(_mixer.load_from(stale) == 0, "a bus that no longer exists is skipped rather than made")

	# A file written before mutes existed has no "muted" key. Defaulting that to
	# muted is a silent game after an update, and the player has no idea why.
	_mixer.set_muted(MUSIC, true)
	_mixer.load_from({String(MUSIC): {"level": 0.8}})
	expect(not _mixer.is_muted(MUSIC), "a saved entry with no mute in it restores unmuted")
	expect(absf(_mixer.level_of(MUSIC) - 0.8) < 0.01, "with the level it does have")

func test_removing_everything() -> void:
	print("cleanup")
	_build()
	var before := AudioServer.bus_count
	_mixer.remove_all()
	expect(AudioServer.bus_count < before, "removing takes the buses away again")
	expect(AudioServer.get_bus_index(MUSIC) == -1, "so the names are free")
	expect(AudioServer.bus_count >= 1, "and the master bus survives, because it always must")
