class_name DemoCatalogue
extends RefCounted

## Reads the collection from disk: which demos exist, what they are called, and
## what each one is about.
##
## The root README is the index everyone else reads, so it is the index this
## reads too — a browser with its own hand-kept list would drift from it within
## a week. Categories, descriptions and order all come from there; tags come
## from each demo's own README line, written by tools/build_tags.py.

## One demo, as the browser needs it.
class Entry extends RefCounted:
	var name: String
	var category: String
	var description: String
	var tags: PackedStringArray

	func _init(demo_name: String, demo_category: String, demo_description: String,
			demo_tags: PackedStringArray) -> void:
		name = demo_name
		category = demo_category
		description = demo_description
		tags = demo_tags

	## Everything the search box matches against.
	func haystack() -> String:
		return "%s %s %s %s" % [name, category, description, " ".join(tags)]


const ROW := "^\\|\\s*\\[([a-z0-9-]+)\\]\\([^)]*\\)\\s*\\|\\s*(.*?)\\s*\\|"
const HEADING := "^###\\s+(.+?)\\s*$"
const TAG_LINE := "<!-- tags:\\s*([^>]*?)\\s*-->"

## Read the collection rooted at `base` — the directory holding the demos.
static func load_from(base: String) -> Array:
	var index := FileAccess.open(base.path_join("README.md"), FileAccess.READ)
	if index == null:
		return []

	var row := RegEx.new()
	row.compile(ROW)
	var heading := RegEx.new()
	heading.compile(HEADING)

	var entries: Array = []
	var category := "Uncategorised"
	while not index.eof_reached():
		var line := index.get_line()
		var head := heading.search(line)
		if head:
			category = _strip_emoji(head.get_string(1))
			continue
		var match := row.search(line)
		if match == null:
			continue
		var name := match.get_string(1)
		if not DirAccess.dir_exists_absolute(base.path_join(name)):
			continue
		entries.append(Entry.new(name, category, match.get_string(2),
			_tags_of(base.path_join(name))))
	index.close()
	return entries


## The tag line tools/build_tags.py wrote into the demo's own README.
static func _tags_of(demo_dir: String) -> PackedStringArray:
	var readme := FileAccess.open(demo_dir.path_join("README.md"), FileAccess.READ)
	if readme == null:
		return PackedStringArray()
	var text := readme.get_as_text()
	readme.close()
	var pattern := RegEx.new()
	pattern.compile(TAG_LINE)
	var match := pattern.search(text)
	if match == null or match.get_string(1) == "none":
		return PackedStringArray()
	var out := PackedStringArray()
	for tag in match.get_string(1).split(","):
		var trimmed := tag.strip_edges()
		if trimmed != "":
			out.append(trimmed)
	return out


## The index headings carry an emoji for the web view; drop it for a list.
static func _strip_emoji(heading_text: String) -> String:
	var out := ""
	for i in heading_text.length():
		var c := heading_text[i]
		if c.unicode_at(0) < 0x2000:
			out += c
	return out.strip_edges()


## The demos matching a search and an optional tag, in index order.
static func filter(entries: Array, search: String, tag: String) -> Array:
	var needle := search.strip_edges().to_lower()
	var out: Array = []
	for entry in entries:
		if tag != "" and not (entry as Entry).tags.has(tag):
			continue
		if needle != "" and not (entry as Entry).haystack().to_lower().contains(needle):
			continue
		out.append(entry)
	return out


## Every tag in use, in the order they appear, so the filter list is stable.
static func tags_in(entries: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for entry in entries:
		for tag in (entry as Entry).tags:
			# The list is its own seen-set. A dictionary alongside it would be
			# faster and, at a dozen tags, would only be a second thing to keep
			# in step with the first.
			if not out.has(tag):
				out.append(tag)
	out.sort()
	return out
