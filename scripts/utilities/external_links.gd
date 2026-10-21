extends RefCounted
class_name ExternalLinks
## Opens external URLs from inside the game.
##
## Web: opens a new tab (popups are blocked unless they come from a user
## gesture — these calls always do).
## Android/iOS: uses the OS URL handler through Godot's OS.execute().
## Desktop: the OS default browser.

const FEEDBACK_URL := "https://github.com/mohsen-niksirat/Horde_Survival_3D_Godot/issues/new"
const ISSUES_URL := "https://github.com/mohsen-niksirat/Horde_Survival_3D_Godot/issues"
const REPO_URL := "https://github.com/mohsen-niksirat/Horde_Survival_3D_Godot"
const CHANGELOG_URL := "https://github.com/mohsen-niksirat/Horde_Survival_3D_Godot/blob/main/CHANGELOG.md"

## Open a URL. Returns true when the request was dispatched.
static func open(url: String) -> bool:
	if url.is_empty():
		return false
	match OS.get_name():
		"Web":
			# JavaScriptBridge.eval runs inside the user-gesture handler, so
			# the popup blocker lets it through.
			JavaScriptBridge.eval(
				"try{window.open('%s','_blank','noopener');}catch(e){window.location.href='%s';}" % [url, url],
				true
			)
			return true
		"Android", "iOS":
			# On Android OS.execute with a URL opens the default browser.
			return OS.execute(url, []) == OK
		_:
			return OS.execute(url, []) == OK

static func open_feedback() -> bool:
	return open(FEEDBACK_URL)

static func open_issues() -> bool:
	return open(ISSUES_URL)

static func open_repo() -> bool:
	return open(REPO_URL)
