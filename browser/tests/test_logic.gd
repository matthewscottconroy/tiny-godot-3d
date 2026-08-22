extends Node

# Drives the real catalogue from scripts/catalogue.gd — see
# docs/TEST_INTEGRITY.md.
#
# The browser reads the collection off disk, so the suite points it at the real
# collection: if the README index changes shape, this fails rather than the
# browser quietly showing an empty list.
#
# Nothing here hard-codes a demo count. The collection is small and growing, so
# an assertion like "more than 100 demos" would either fail today or have to be
# edited every time one is added. The invariants that matter — every listed demo
# is a real folder, every one carries a category and a description, search and
# tag filters compose — hold at any size.

var _pass := 0
var _fail := 0

func _ready() -> void:
	_test_it_finds_the_collection()
	_test_it_finds_every_demo_on_disk()
	_test_every_entry_is_a_real_demo()
	_test_entries_carry_their_category()
	_test_entries_carry_a_description()
	_test_tags_are_read_from_each_demo()
	_test_search_matches_names_and_descriptions()
	_test_search_is_case_insensitive()
	_test_an_empty_search_shows_everything()
	_test_a_search_that_matches_nothing_is_empty()
	_test_filtering_by_tag()
	_test_search_and_tag_together()
	_test_the_tag_list_is_sorted_and_unique()
	_test_a_missing_collection_is_handled()
	_test_a_demo_without_a_tag_line_is_read_anyway()
	_report()

func expect(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)

func _report() -> void:
	var summary := "[browser] %d/%d passed" % [_pass, _pass + _fail]
	print(summary)
	if _fail > 0:
		push_error(summary)

const Catalogue := preload("res://scripts/catalogue.gd")

## Directories with a project.godot that are tools rather than demos. The
## browser itself is the only one, and the Python tools skip it by the same name.
const NOT_A_DEMO := ["browser"]

var _root: String = ProjectSettings.globalize_path("res://..")
var _entries: Array = []

func _load() -> Array:
	if _entries.is_empty():
		_entries = Catalogue.load_from(_root)
	return _entries

## Every demo folder actually on disk, which is what the index is checked against.
func _demo_dirs() -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(_root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with(".") \
				and not NOT_A_DEMO.has(entry) \
				and FileAccess.file_exists(_root.path_join(entry).path_join("project.godot")):
			found.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found

func _test_it_finds_the_collection() -> void:
	print("the collection")
	var entries := _load()
	expect(entries.size() > 0, "the browser reads the collection (%d demos)" % entries.size())

func _test_it_finds_every_demo_on_disk() -> void:
	print("nothing missed")
	var entries := _load()
	var listed := {}
	for entry in entries:
		listed[entry.name] = true
	begin_quiet()
	for demo in _demo_dirs():
		# A demo that exists but is not in the index cannot be launched from
		# here — and check_docs.py fails on the same thing from the other side.
		expect_quiet(listed.has(demo), "%s is on disk but not in the index" % demo)
	expect(_quiet_failures == 0, "every demo folder on disk is in the index")
	expect(not listed.has("browser"), "and the browser itself is not one of them")

func _test_every_entry_is_a_real_demo() -> void:
	print("real folders")
	var entries := _load()
	var missing := 0
	for entry in entries:
		# A row in the index naming a folder that is not there would show a
		# demo that cannot be launched.
		if not DirAccess.dir_exists_absolute(_root.path_join(entry.name)):
			missing += 1
	expect(missing == 0, "every listed demo is a folder that exists")

func _test_entries_carry_their_category() -> void:
	print("categories")
	var entries := _load()
	var categories := {}
	begin_quiet()
	for entry in entries:
		categories[entry.category] = true
		expect_quiet(entry.category != "" and entry.category != "Uncategorised",
			"%s has no category" % entry.name)
	expect(_quiet_failures == 0, "every demo carries the category it is indexed under")
	expect(categories.size() > 1, "and the categories are the index's, not one bucket")
	# The index headings carry an emoji the browser strips. Stripping the words
	# instead leaves a heading that is still non-empty and completely useless.
	var readable := false
	for category in categories:
		if (category as String).length() > 3 and (category as String).to_lower().contains("camera"):
			readable = true
	expect(readable, "and read as words, not as the emoji in front of them")

func _test_entries_carry_a_description() -> void:
	print("descriptions")
	var entries := _load()
	begin_quiet()
	for entry in entries:
		expect_quiet(entry.description.length() > 10, "%s has no description" % entry.name)
	expect(_quiet_failures == 0, "every demo carries its one-line description")

func _test_tags_are_read_from_each_demo() -> void:
	print("tags")
	var entries := _load()
	var tagged := 0
	for entry in entries:
		if entry.tags.size() > 0:
			tagged += 1
	# Read from each demo's own README rather than a list here, so the browser
	# cannot disagree with tools/build_tags.py.
	expect(tagged == entries.size(), "every demo comes with tags (%d of %d)"
		% [tagged, entries.size()])

func _test_search_matches_names_and_descriptions() -> void:
	print("searching")
	var entries := _load()
	var by_name := Catalogue.filter(entries, "orbit", "")
	expect(by_name.size() >= 1, "a search matches a demo by name")
	var found := false
	for entry in by_name:
		if entry.name == "orbit-camera":
			found = true
	expect(found, "and finds the one it names")

	var by_text := Catalogue.filter(entries, "camera", "")
	expect(by_text.size() >= 1, "a search matches words from a description too")

func _test_search_is_case_insensitive() -> void:
	print("case")
	var entries := _load()
	expect(Catalogue.filter(entries, "ORBIT", "").size()
		== Catalogue.filter(entries, "orbit", "").size(),
		"searching is case insensitive")

func _test_an_empty_search_shows_everything() -> void:
	print("no search")
	var entries := _load()
	expect(Catalogue.filter(entries, "", "").size() == entries.size(),
		"an empty search hides nothing")
	expect(Catalogue.filter(entries, "   ", "").size() == entries.size(),
		"and neither does a search of spaces")

func _test_a_search_that_matches_nothing_is_empty() -> void:
	print("no matches")
	var entries := _load()
	expect(Catalogue.filter(entries, "zzzzz-not-a-demo", "").is_empty(),
		"a search matching nothing returns nothing rather than everything")

func _test_filtering_by_tag() -> void:
	print("tag filter")
	var entries := _load()
	# `component` is carried by some demos and not others whatever the
	# collection grows into, which is what makes it a useful filter to check.
	var components := Catalogue.filter(entries, "", "component")
	expect(components.size() > 0, "filtering by a tag finds demos")
	begin_quiet()
	for entry in components:
		expect_quiet(entry.tags.has("component"), "%s does not carry the tag" % entry.name)
	expect(_quiet_failures == 0, "and every one of them carries it")
	expect(Catalogue.filter(entries, "", "no-such-tag").is_empty(),
		"while a tag nothing carries leaves the list empty rather than full")

func _test_search_and_tag_together() -> void:
	print("both at once")
	var entries := _load()
	var both := Catalogue.filter(entries, "camera", "component")
	begin_quiet()
	for entry in both:
		expect_quiet(entry.tags.has("component"), "%s slipped past the tag" % entry.name)
		expect_quiet(entry.haystack().to_lower().contains("camera"),
			"%s slipped past the search" % entry.name)
	expect(_quiet_failures == 0, "a search and a tag together apply both, not either")
	expect(both.size() <= Catalogue.filter(entries, "", "component").size(),
		"so the pair never matches more than the tag alone")

func _test_the_tag_list_is_sorted_and_unique() -> void:
	print("the tag bar")
	var entries := _load()
	var tags := Catalogue.tags_in(entries)
	expect(tags.size() > 1, "there are tags to filter by")
	var seen := {}
	var sorted := true
	var previous := ""
	for tag in tags:
		if seen.has(tag):
			expect(false, "the tag list repeats %s" % tag)
		seen[tag] = true
		if previous != "" and tag < previous:
			sorted = false
		previous = tag
	expect(sorted, "the tag list is in order, so the buttons do not move about")

func _test_a_missing_collection_is_handled() -> void:
	print("no collection")
	# Run from somewhere without a README, the browser should come up empty and
	# say so rather than failing to open.
	expect(Catalogue.load_from("/nonexistent-directory").is_empty(),
		"a missing collection reads as no demos rather than an error")

func _test_a_demo_without_a_tag_line_is_read_anyway() -> void:
	print("ungenerated tags")
	# A demo scaffolded but not yet passed through tools/build_tags.py has no
	# tag line, and one that uses nothing taggable has the literal "none". Both
	# have to read as "no tags" — the browser is the thing you would reach for
	# to look at a demo you just created, so it cannot be the thing that breaks
	# on it.
	var base := _fake_collection()
	if base == "":
		expect(false, "could not write a scratch collection to test against")
		return
	var entries := Catalogue.load_from(base)
	expect(entries.size() == 2, "both scratch demos are read")
	begin_quiet()
	for entry in entries:
		expect_quiet(entry.tags.is_empty(), "%s came back with tags it does not have" % entry.name)
	expect(_quiet_failures == 0, "a demo with no tag line, or a tag line of 'none', reads as no tags")

## Write a two-demo collection under user:// and return its absolute path.
func _fake_collection() -> String:
	var base := ProjectSettings.globalize_path("user://scratch-collection")
	for demo in ["no-tag-line", "tagged-none"]:
		if DirAccess.make_dir_recursive_absolute(base.path_join(demo)) != OK:
			return ""
	if not _write(base.path_join("README.md"), "\n".join([
			"# Scratch",
			"",
			"### Movement",
			"| Demo | Description |",
			"|------|-------------|",
			"| [no-tag-line](no-tag-line) | Scaffolded, not yet passed through build_tags.py. |",
			"| [tagged-none](tagged-none) | Uses nothing any tag describes. |",
			""])):
		return ""
	if not _write(base.path_join("no-tag-line/README.md"), "# No Tag Line\n\nNothing here yet.\n"):
		return ""
	if not _write(base.path_join("tagged-none/README.md"),
			"# Tagged None\n\n<!-- tags: none -->\n\nNothing taggable.\n"):
		return ""
	return base

func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true

var _quiet_failures := 0

## Zero the tally, so one test's failures cannot cascade into the next.
func begin_quiet() -> void:
	_quiet_failures = 0

func expect_quiet(cond: bool, label: String) -> void:
	if not cond:
		_quiet_failures += 1
		print("  (", label, " — failed)")
