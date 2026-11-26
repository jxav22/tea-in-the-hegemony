class_name PortraitBank
extends RefCounted
## Resolves portrait/silhouette paths by character_id + expression (CSP-replaceable).

const PORTRAIT_DIR := "res://assets/portraits/"
const SILHOUETTE_DIR := "res://assets/silhouettes/"
const BG_DIR := "res://assets/backgrounds/"

const EXPRESSIONS := ["neutral", "amused", "suspicious", "flustered", "cold"]


static func portrait_path(character_id: String, expression: String = "neutral") -> String:
	var expr := expression if expression in EXPRESSIONS else "neutral"
	var path := "%s%s_%s.png" % [PORTRAIT_DIR, character_id, expr]
	if ResourceLoader.exists(path):
		return path
	var fallback := "%s%s_neutral.png" % [PORTRAIT_DIR, character_id]
	if ResourceLoader.exists(fallback):
		return fallback
	return ""


static func silhouette_path(character_id: String) -> String:
	var path := "%s%s_sil.png" % [SILHOUETTE_DIR, character_id]
	return path if ResourceLoader.exists(path) else ""


static func background_path(location_id: String) -> String:
	var path := "%s%s_bg.png" % [BG_DIR, location_id]
	return path if ResourceLoader.exists(path) else ""


static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
