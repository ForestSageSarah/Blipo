extends Node2D
# =============================================================================
# Blipo - core gameplay
# =============================================================================
# The whole game lives in this one commented file so you can read it top to
# bottom and learn how Godot 4 works. It is ordered the way the game runs.
#
# What works now:
#   - intro screen with a selectable starting speed (Low / Medium / High)
#   - the 8 x 16 box with a falling two-Blip pair
#   - move / rotate / soft-drop, with collision against walls, floor, Blips
#   - locking, and gravity so a Blip left hanging over a gap drops on its own
#   - matching (4+ of a color in a row or column clear) and cascade chains
#   - target Blips seeded at the start; clear them ALL to win the level
#   - a speed ramp that quickens the fall the longer the level runs
#   - a visible HUD: score, targets left, current speed
#   - pause with a dim PAUSED overlay, plus a volume slider and a mute button
#   - four music tracks that switch with the game state
#   - game over when the box fills to the spawn point
#
# Still to come: real Blip art and audio polish (Phase 4).
#
# Godot ideas in here:
#   - "extends Node2D": this script IS a 2D node and can paint via _draw().
#   - _ready() runs once on load. _process(delta) runs every frame. _input()
#     fires on input. We never paint directly; we call queue_redraw().
#   - An enum + one "state" variable is a tiny state machine: the game is in
#     exactly one of INTRO / PLAYING / PAUSED / GAME_OVER / WIN at a time.
#   - AudioStreamPlayer plays sound. Control nodes (HSlider, Button) are the UI
#     widgets; we build them in code and show them only while paused.
# =============================================================================


enum State { SPLASH, INTRO, PLAYING, PAUSED, GAME_OVER, WIN }


# ----- Constants (the knobs you would tune) ----------------------------------

const COLS: int = 8
const ROWS: int = 16
const CELL: int = 32
const EMPTY: int = -1
const MATCH_LEN: int = 4              # how many in a line it takes to clear

const ORIGIN: Vector2 = Vector2(40, 40)
const VIEW_W: int = 600
const VIEW_H: int = 620
const FRAME_BORDER: int = 24   # the playfield frame's border thickness (px around the 256x512 opening)

# Dancing title/banner animation (the BLIPO logo and the PAUSED/GAME OVER/WIN text)
const DANCE_BOB_AMP: float = 8.0      # how far each letter bobs up and down (px)
const DANCE_BOB_SPEED: float = 6.0    # how fast the bob wave moves
const DANCE_BOB_PHASE: float = 0.6    # phase shift per letter, so the wave travels
const DANCE_COLOR_SPEED: float = 2.5  # how fast letters step through Red/Green/Blue

const SPLASH_TEXT: String = "FOREST SAGE SARAH"
const SPLASH_SUBTITLE: String = ""
const SPLASH_EMBOLDEN: float = 0.7   # faux-bold weight for the splash font (Marck Script ships single-weight)
const SPLASH_DROP_STAGGER: float = 0.05
const SPLASH_DROP_TIME: float = 0.34
const SPLASH_DROP_FROM: float = -72.0
const SPLASH_FADE_OUT_TIME: float = 0.45
const INTRO_FADE_IN_TIME: float = 0.55
const SPLASH_RAINBOW_COLORS: Array = [
	Color("ff4500"), # Orange-Red
	Color("ff8c00"), # Dark Orange
	Color("ffd700"), # Gold
	Color("32cd32"), # Lime Green
	Color("00ced1"), # Dark Turquoise
	Color("1e90ff"), # Dodger Blue
	Color("9370db"), # Medium Purple
]

const BLIP_COLORS: Array = [
	Color(0.90, 0.25, 0.25),   # 0 = Red
	Color(0.45, 0.80, 0.30),   # 1 = Green
	Color(0.30, 0.55, 0.95),   # 2 = Blue
]

const TITLE: String = "BLIPO"
const VERSION: String = "v0.2"
const AUTHOR: String = "by Forest Sage Sarah"

# Text shown on the Instructions and Credits overlays. Edit freely.
const HELP_TEXT: String = "Match four or more Blips of the same color in a row or column to clear them.\n\nClear every target Blip (the grumpy-faced ones) to win the level.\n\nClearing Blips makes the ones above fall, which can chain into more clears for bonus points.\n\nDo not let the stack reach the top.\n\nCONTROLS\nMove:  Left / A,  Right / D\nRotate:  Up / W / X   (Z rotates the other way)\nSoft drop:  hold Down / S\nInstant drop:  tap Down twice\nPause:  P or Esc\nRestart:  R"
const CREDITS_TEXT: String = "BLIPO\nGame, art, and design by Sarah Copeland\nhttps://ForestSageSarah.com\n\nSound effects\nJDSherbert - Pixel Game Essentials SFX Pack\n\nUI art\nCrusenho - Complete UI Essential Pack (CC BY 4.0)\n\nFonts\nModak, Play, and Marck Script (Google Fonts, OFL)\n\nMusic\nPudgyplatypus - Royalty Free Game Music Loops (OpenGameArt)\n\nMade with Godot Engine"

# Speed presets chosen on the intro screen. Each number is the seconds the pair
# takes to fall one row at the start of a level (smaller = faster).
const SPEED_NAMES: Array = ["Low", "Medium", "High"]
const SPEED_INTERVALS: Array = [0.9, 0.6, 0.4]

const SOFT_DROP_INTERVAL: float = 0.05   # fall interval while holding soft-drop
const DOUBLE_TAP_MS: int = 300           # tap Down twice within this window to hard-drop
const POP_TIME: float = 0.28             # how long the pop sprite lingers when a Blip clears
const SFX_VOLUME_DB: float = -6.0        # sound-effect level (Mute still silences them)
const MIN_INTERVAL: float = 0.12         # the fastest the ramp will ever go
const RAMP_EVERY_LOCKS: int = 6          # speed up a notch every N locked pairs
const RAMP_FACTOR: float = 0.92          # multiply the interval by this each ramp

const STARTING_TARGETS: int = 6          # how many target Blips to seed
const TARGET_TOP_ROW: int = 6            # never seed targets above this row
const DANGER_ROWS: int = 3               # locked Blips this near the top = danger

# Music track indexes into the music_streams array.
const TRACK_END: int = 0      # 8Bit_1.wav
const TRACK_PAUSE: int = 1    # 8Bit_4.wav
const GAMEPLAY_TRACK_OFFSET: int = 2
const GAMEPLAY_MUSIC_NAMES: Array = ["80s Retro", "DnB", "HipHop Noir", "House"]


# ----- Runtime state ---------------------------------------------------------

var state: int = State.INTRO
var grid: Array = []              # grid[row][col] = color index, or EMPTY
var targets: Array = []           # targets[row][col] = true if that Blip is a target
var pair_cell_a: Vector2i
var pair_orient: int = 0
var color_a: int = 0
var color_b: int = 0
var fall_timer: float = 0.0
var soft_dropping: bool = false
var last_down_ms: int = -100000   # timestamp of the last Down tap, for double-tap hard-drop
var score: int = 0
var level: int = 1
var anim_time: float = 0.0   # ever-increasing clock that drives the dancing text

var speed_choice: int = 1                 # index into SPEED_NAMES (default Medium)
var current_fall_interval: float = 0.6    # the live interval, ramps down over time
var locks_since_ramp: int = 0
var intro_alpha: float = 1.0
var transition_active: bool = false

# Audio
var music_player: AudioStreamPlayer
var music_streams: Array = []
var current_track: int = -1
var music_volume: float = 0.35
var music_muted: bool = false
var gameplay_music_choice: int = 0

# Sound effects. A small pool of players lets several effects overlap.
var sfx_players: Array = []
var sfx_idx: int = 0
var sfx_match: AudioStream    # a match clears (Blips "blip out")
var sfx_land: AudioStream     # a pair locks into place
var sfx_win: AudioStream      # level complete
var sfx_fail: AudioStream     # level failed (game over)
var sfx_drop: AudioStream     # instant / hard drop

# Pause-screen UI (built in code)
var splash_ui: Control
var main_title: HBoxContainer
var subtitle_label: Label
var splash_animation_player: AnimationPlayer
var splash_chime_player: AudioStreamPlayer
var splash_shine_material: ShaderMaterial
var splash_letters: Array = []
var intro_ui: Control
var speed_buttons: Array = []
var start_button: Button
var pause_ui: Control
var volume_slider: HSlider
var music_selector: OptionButton
var mute_button: Button
var end_ui: Control
var restart_button: Button
var help_panel: Control      # "How to play" overlay (from the pause menu)
var credits_panel: Control   # Credits overlay (from intro and pause)

# UI sprites
var icon_play: Texture2D
var icon_check: Texture2D
var icon_point: Texture2D
var icon_cross: Texture2D
var icon_line: Texture2D
var volume_bar_tex: Texture2D
var volume_handle_tex: Texture2D

# Art
var frame_tex: Texture2D   # the playfield frame drawn in LibreSprite (res://playfield.png)

# Blip art, indexed by color (0 = Red, 1 = Green, 2 = Blue). A null entry means
# "no art yet for this color", so _draw_blip falls back to a placeholder square.
var blip_idle: Array = [null, null, null]
var blip_bad: Array = [null, null, null]
var blip_pop: Array = [null, null, null]
var pop_effects: Array = []   # transient { pos, color, t } shown when Blips clear

# Fonts (null-safe: fall back to Godot's default font if a file is missing)
var font_title: Font    # Modak, used for the BLIPO logo
var font_ui: Font       # Play, used for all UI text
var font_splash: Font   # Marck Script, used for the splash screen


# ----- Setup -----------------------------------------------------------------

func _ready() -> void:
	randomize()
	_new_grid()
	frame_tex = load("res://playfield.png")   # null-safe: falls back to a drawn border if missing
	if ResourceLoader.exists("res://fonts/Modak-Regular.ttf"):
		font_title = load("res://fonts/Modak-Regular.ttf")
	if ResourceLoader.exists("res://fonts/Play-Regular.ttf"):
		font_ui = load("res://fonts/Play-Regular.ttf")
	if ResourceLoader.exists("res://fonts/MarckScript-Regular.ttf"):
		# Wrap the single-weight script font in a FontVariation to fake a bolder weight.
		var splash_base: Font = load("res://fonts/MarckScript-Regular.ttf")
		var fv: FontVariation = FontVariation.new()
		fv.base_font = splash_base
		fv.variation_embolden = SPLASH_EMBOLDEN
		font_splash = fv
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # keep pixel art crisp at 1:1
	_load_ui_sprites()
	_load_blip_sprites()
	_build_audio()
	_build_splash_ui()
	_build_intro_ui()
	_build_pause_ui()
	_build_end_ui()
	_build_overlays()
	state = State.SPLASH
	_sync_ui()
	queue_redraw()
	_update_music()
	call_deferred("_play_splash")


# Build a fresh, empty grid and a matching empty targets grid.
func _new_grid() -> void:
	grid = []
	targets = []
	for r in range(ROWS):
		var grow: Array = []
		var trow: Array = []
		for c in range(COLS):
			grow.append(EMPTY)
			trow.append(false)
		grid.append(grow)
		targets.append(trow)


# ----- Audio -----------------------------------------------------------------

func _build_audio() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	# WAV files do not always carry loop info, so we loop manually: when a track
	# finishes, we just start it again.
	music_player.finished.connect(_on_music_finished)
	music_streams = [
		load("res://audio/8Bit_1.wav"),
		load("res://audio/8Bit_4.wav"),
		load("res://audio/80sRetro_1.wav"),
		load("res://audio/DnB_1.wav"),
		load("res://audio/HipHopNoir_1.wav"),
		load("res://audio/House_1.wav"),
	]
	_apply_audio()

	# Sound-effect player pool (4 voices, round-robin so effects can overlap).
	for i in range(4):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	sfx_match = _sfx("blip_match.ogg")
	sfx_land = _sfx("JDSherbert - Pixel Game Essentials SFX Pack - Footstep 1.ogg")
	sfx_win = _sfx("JDSherbert - Pixel Game Essentials SFX Pack - Level Complete 1.ogg")
	sfx_fail = _sfx("JDSherbert - Pixel Game Essentials SFX Pack - Level Fail 1.ogg")
	sfx_drop = _sfx("JDSherbert - Pixel Game Essentials SFX Pack - Shoot 1.ogg")


func _on_music_finished() -> void:
	if current_track >= 0:
		music_player.play()


# Load a sound effect from the audio folder, or null if it is missing.
func _sfx(filename: String) -> AudioStream:
	var path: String = "res://audio/" + filename
	if ResourceLoader.exists(path):
		return load(path)
	return null


# Play a sound effect on the next free pool voice. Mute silences effects too.
func _play_sfx(stream: AudioStream) -> void:
	if stream == null or music_muted or sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = sfx_players[sfx_idx]
	sfx_idx = (sfx_idx + 1) % sfx_players.size()
	p.stream = stream
	p.volume_db = SFX_VOLUME_DB
	p.play()


# Push the current volume/mute settings onto the player.
func _apply_audio() -> void:
	if music_muted or music_volume <= 0.0:
		music_player.volume_db = -80.0   # effectively silent
	else:
		music_player.volume_db = linear_to_db(music_volume)


# Which track should be playing right now, given the state.
func _desired_track() -> int:
	match state:
		State.SPLASH:
			return -1
		State.INTRO:
			return -1
		State.PAUSED:
			return GAMEPLAY_TRACK_OFFSET + gameplay_music_choice
		State.PLAYING:
			return GAMEPLAY_TRACK_OFFSET + gameplay_music_choice
		_:
			return TRACK_END   # game over and win use the end-screen tune


# Switch tracks only when the desired one changes, so it does not restart every frame.
func _update_music() -> void:
	var want: int = _desired_track()
	if want == current_track:
		return
	current_track = want
	if want < 0:
		music_player.stop()
	elif want < music_streams.size() and music_streams[want] != null:
		music_player.stream = music_streams[want]
		_apply_audio()
		music_player.play()


# Danger = any LOCKED Blip sitting in the top few rows (the stack is getting high).
func _is_danger() -> bool:
	for r in range(DANGER_ROWS):
		for c in range(COLS):
			if grid[r][c] != EMPTY:
				return true
	return false


# ----- UI --------------------------------------------------------------------

func _build_splash_ui() -> void:
	splash_ui = Control.new()
	splash_ui.name = "SplashScreen"
	splash_ui.size = Vector2(VIEW_W, VIEW_H)
	splash_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(splash_ui)

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.98, 0.97, 0.93)
	background.size = Vector2(VIEW_W, VIEW_H)
	splash_ui.add_child(background)

	var center: VBoxContainer = VBoxContainer.new()
	center.name = "SplashCenter"
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.position = Vector2(32, 210)
	center.custom_minimum_size = Vector2(VIEW_W - 64, 150)
	splash_ui.add_child(center)

	main_title = HBoxContainer.new()
	main_title.name = "MainTitle"
	main_title.alignment = BoxContainer.ALIGNMENT_CENTER
	main_title.add_theme_constant_override("separation", 2)
	center.add_child(main_title)

	splash_shine_material = ShaderMaterial.new()
	var shine_shader: Shader = Shader.new()
	shine_shader.code = """
shader_type canvas_item;

uniform float shine_pos = -0.35;
uniform float shine_width = 0.16;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	float left_edge = smoothstep(shine_pos - shine_width, shine_pos, UV.x);
	float right_edge = 1.0 - smoothstep(shine_pos, shine_pos + shine_width, UV.x);
	float shine = left_edge * right_edge;
	COLOR = vec4(base_color.rgb + vec3(shine * 0.9) * base_color.a, base_color.a);
}
"""
	splash_shine_material.shader = shine_shader
	splash_shine_material.set_shader_parameter("shine_pos", -0.35)
	main_title.material = splash_shine_material

	_populate_splash_letters()

	subtitle_label = Label.new()
	subtitle_label.name = "Subtitle"
	subtitle_label.text = SPLASH_SUBTITLE
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.modulate = Color(0.02, 0.05, 0.18, 0.0)
	subtitle_label.custom_minimum_size = Vector2(VIEW_W - 64, 34)
	if font_ui != null:
		subtitle_label.add_theme_font_override("font", font_ui)
	subtitle_label.add_theme_font_size_override("font_size", 28)
	center.add_child(subtitle_label)

	splash_animation_player = AnimationPlayer.new()
	splash_animation_player.name = "AnimationPlayer"
	splash_ui.add_child(splash_animation_player)

	splash_chime_player = AudioStreamPlayer.new()
	splash_chime_player.name = "AudioStreamPlayer"
	if ResourceLoader.exists("res://audio/blip_match.ogg"):
		splash_chime_player.stream = load("res://audio/blip_match.ogg")
	splash_chime_player.finished.connect(_finish_splash)
	splash_ui.add_child(splash_chime_player)


func _populate_splash_letters() -> void:
	for child in main_title.get_children():
		child.queue_free()
	splash_letters = []

	for i in range(SPLASH_TEXT.length()):
		var letter: String = SPLASH_TEXT[i]
		var slot: Control = Control.new()
		slot.name = "LetterSlot_" + str(i)
		slot.custom_minimum_size = Vector2(20, 60) if letter == " " else Vector2(28, 60)
		slot.use_parent_material = true
		main_title.add_child(slot)

		var label: Label = Label.new()
		label.name = "Letter_" + str(i)
		label.text = letter
		label.position.y = SPLASH_DROP_FROM
		label.use_parent_material = true
		label.add_theme_font_size_override("font_size", 44)
		var sfont: Font = font_splash if font_splash != null else font_ui
		if sfont != null:
			label.add_theme_font_override("font", sfont)
		if letter != " ":
			label.modulate = SPLASH_RAINBOW_COLORS[i % SPLASH_RAINBOW_COLORS.size()]
		else:
			label.custom_minimum_size.x = 20
		label.modulate.a = 0.0
		slot.add_child(label)
		splash_letters.append(label)


func _play_splash() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for i in range(splash_letters.size()):
		var letter := splash_letters[i] as Label
		tween.tween_property(letter, "position:y", 0.0, SPLASH_DROP_TIME).set_delay(i * SPLASH_DROP_STAGGER).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(letter, "modulate:a", 1.0, SPLASH_DROP_TIME).set_delay(i * SPLASH_DROP_STAGGER).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var final_drop_time: float = (splash_letters.size() - 1) * SPLASH_DROP_STAGGER + SPLASH_DROP_TIME
	tween.tween_callback(_flash_splash_subtitle).set_delay(final_drop_time)
	tween.tween_method(_set_splash_shine, -0.35, 1.35, 0.55).set_delay(final_drop_time)


func _flash_splash_subtitle() -> void:
	if subtitle_label.text != "":
		subtitle_label.modulate.a = 1.0
	if splash_chime_player.stream != null:
		splash_chime_player.play()
	else:
		_finish_splash()


func _set_splash_shine(value: float) -> void:
	if splash_shine_material != null:
		splash_shine_material.set_shader_parameter("shine_pos", value)


func _finish_splash() -> void:
	splash_chime_player.stop()
	transition_active = true
	var tween: Tween = create_tween()
	tween.tween_property(splash_ui, "modulate:a", 0.0, SPLASH_FADE_OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(_show_intro_after_splash)


func _show_intro_after_splash() -> void:
	state = State.INTRO
	intro_alpha = 0.0
	_sync_ui()
	_update_music()
	queue_redraw()
	var tween: Tween = create_tween()
	tween.tween_method(_set_intro_alpha, 0.0, 1.0, INTRO_FADE_IN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_intro_fade)


func _set_intro_alpha(value: float) -> void:
	intro_alpha = value
	if intro_ui != null:
		intro_ui.modulate.a = value
	queue_redraw()


func _finish_intro_fade() -> void:
	transition_active = false
	_set_intro_alpha(1.0)

func _ui_texture(filename: String) -> Texture2D:
	var path: String = "res://Sprites/" + filename
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _load_ui_sprites() -> void:
	icon_play = _ui_texture("UI_Flat_IconPlay01a.png")
	icon_check = _ui_texture("UI_Flat_IconCheck01a.png")
	icon_point = _ui_texture("UI_Flat_IconPoint01a.png")
	icon_cross = _ui_texture("UI_Flat_IconCross01a.png")
	icon_line = _ui_texture("UI_Flat_IconLine01a.png")
	volume_bar_tex = _ui_texture("UI_Flat_Bar01a.png")
	volume_handle_tex = _ui_texture("UI_Flat_Handle05a.png")


func _blip_texture(filename: String) -> Texture2D:
	var path: String = "res://Sprites/Blip/" + filename
	if ResourceLoader.exists(path):
		return load(path)
	return null


# Load the Blip art by color. Filenames follow the green set's pattern, so
# dropping in Red or Blue art with the same names (Blip_Red_Idle.png,
# Bad_Blip_Red.png, Blip_Pop_Red.png, and the Blue versions) makes them load
# automatically, no code change needed. Missing files stay null and fall back
# to placeholder squares.
func _load_blip_sprites() -> void:
	var color_names: Array = ["Red", "Green", "Blue"]
	for i in range(color_names.size()):
		var n: String = color_names[i]
		blip_idle[i] = _blip_texture("Blip_%s_Idle.png" % n)
		blip_bad[i] = _blip_texture("Bad_Blip_%s.png" % n)
		blip_pop[i] = _blip_texture("Blip_Pop_%s.png" % n)


func _make_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = pos
	button.custom_minimum_size = size
	if font_ui != null:
		button.add_theme_font_override("font", font_ui)
	return button


func _flat_slider_style(color: Color, height: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_top = height
	style.content_margin_bottom = height
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _build_intro_ui() -> void:
	intro_ui = Control.new()
	intro_ui.visible = true
	add_child(intro_ui)

	speed_buttons = []
	var button_w: float = 104.0
	var gap: float = 10.0
	var total_w: float = SPEED_NAMES.size() * button_w + (SPEED_NAMES.size() - 1) * gap
	var x: float = (VIEW_W - total_w) * 0.5
	for i in range(SPEED_NAMES.size()):
		var button: Button = _make_button(SPEED_NAMES[i], Vector2(x + i * (button_w + gap), 330), Vector2(button_w, 34))
		button.toggle_mode = true
		button.icon = icon_point
		button.pressed.connect(_on_speed_button_pressed.bind(i))
		intro_ui.add_child(button)
		speed_buttons.append(button)

	start_button = _make_button("Start", Vector2((VIEW_W - 160) * 0.5, 388), Vector2(160, 42))
	start_button.icon = icon_play
	start_button.pressed.connect(_start_game)
	intro_ui.add_child(start_button)

	var intro_credits: Button = _make_button("Credits", Vector2((VIEW_W - 160) * 0.5, 440), Vector2(160, 38))
	intro_credits.pressed.connect(_show_credits)
	intro_ui.add_child(intro_credits)


func _build_pause_ui() -> void:
	pause_ui = Control.new()
	pause_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE   # let the children catch clicks
	pause_ui.visible = false
	add_child(pause_ui)

	var label: Label = Label.new()
	label.text = "Music volume"
	label.position = Vector2(ORIGIN.x, ORIGIN.y + 330)
	label.add_theme_color_override("font_color", Color.WHITE)
	if font_ui != null:
		label.add_theme_font_override("font", font_ui)
	pause_ui.add_child(label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = music_volume
	volume_slider.custom_minimum_size = Vector2(180, 20)
	volume_slider.position = Vector2(ORIGIN.x, ORIGIN.y + 358)
	volume_slider.add_theme_stylebox_override("slider", _flat_slider_style(Color(0.08, 0.08, 0.12), 3.0))
	volume_slider.add_theme_stylebox_override("grabber_area", _flat_slider_style(Color(0.90, 0.90, 0.60), 3.0))
	volume_slider.add_theme_stylebox_override("grabber_area_highlight", _flat_slider_style(Color(1.0, 1.0, 0.75), 3.0))
	if volume_handle_tex != null:
		volume_slider.add_theme_icon_override("grabber", volume_handle_tex)
		volume_slider.add_theme_icon_override("grabber_highlight", volume_handle_tex)
	pause_ui.add_child(volume_slider)
	volume_slider.value_changed.connect(_on_volume_changed)

	var music_label: Label = Label.new()
	music_label.text = "Music track"
	music_label.position = Vector2(ORIGIN.x, ORIGIN.y + 392)
	music_label.add_theme_color_override("font_color", Color.WHITE)
	if font_ui != null:
		music_label.add_theme_font_override("font", font_ui)
	pause_ui.add_child(music_label)

	music_selector = OptionButton.new()
	music_selector.position = Vector2(ORIGIN.x, ORIGIN.y + 420)
	music_selector.custom_minimum_size = Vector2(180, 32)
	if font_ui != null:
		music_selector.add_theme_font_override("font", font_ui)
	for track_name in GAMEPLAY_MUSIC_NAMES:
		music_selector.add_item(track_name)
	music_selector.item_selected.connect(_on_music_selected)
	pause_ui.add_child(music_selector)

	mute_button = Button.new()
	mute_button.toggle_mode = true
	mute_button.text = "Mute"
	mute_button.icon = icon_line
	mute_button.position = Vector2(ORIGIN.x, ORIGIN.y + 460)
	if font_ui != null:
		mute_button.add_theme_font_override("font", font_ui)
	pause_ui.add_child(mute_button)
	mute_button.toggled.connect(_on_mute_toggled)

	var reset_button: Button = _make_button("Reset", Vector2(ORIGIN.x + 136, ORIGIN.y + 460), Vector2(116, 34))
	reset_button.icon = icon_play
	reset_button.pressed.connect(_start_game)
	pause_ui.add_child(reset_button)

	var help_button: Button = _make_button("Instructions", Vector2(ORIGIN.x, 566), Vector2(150, 38))
	help_button.pressed.connect(_show_help)
	pause_ui.add_child(help_button)

	var pause_credits: Button = _make_button("Credits", Vector2(ORIGIN.x + 162, 566), Vector2(150, 38))
	pause_credits.pressed.connect(_show_credits)
	pause_ui.add_child(pause_credits)


func _build_end_ui() -> void:
	end_ui = Control.new()
	end_ui.visible = false
	add_child(end_ui)

	restart_button = _make_button("Restart", Vector2((VIEW_W - 160) * 0.5, 374), Vector2(160, 42))
	restart_button.icon = icon_play
	restart_button.pressed.connect(_start_game)
	end_ui.add_child(restart_button)


func _build_overlays() -> void:
	help_panel = _build_text_overlay("HOW TO PLAY", HELP_TEXT)
	credits_panel = _build_text_overlay("CREDITS", CREDITS_TEXT)


# Build a full-window text overlay (dim background, title, body, Back button).
# Used for both the Instructions and Credits screens.
func _build_text_overlay(title_text: String, body_text: String) -> Control:
	var panel: Control = Control.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.94)
	bg.position = Vector2.ZERO
	bg.size = Vector2(VIEW_W, VIEW_H)
	panel.add_child(bg)

	var heading: Label = Label.new()
	heading.text = title_text
	heading.position = Vector2(0, 44)
	heading.size = Vector2(VIEW_W, 44)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color.WHITE)
	if font_ui != null:
		heading.add_theme_font_override("font", font_ui)
	panel.add_child(heading)

	var body: Label = Label.new()
	body.text = body_text
	body.position = Vector2(46, 112)
	body.size = Vector2(VIEW_W - 92, 410)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0.90, 0.90, 0.94))
	if font_ui != null:
		body.add_theme_font_override("font", font_ui)
	panel.add_child(body)

	var back: Button = _make_button("Back", Vector2((VIEW_W - 140) * 0.5, 558), Vector2(140, 40))
	back.icon = icon_cross
	back.pressed.connect(_close_overlays)
	panel.add_child(back)

	return panel


func _show_help() -> void:
	credits_panel.visible = false
	help_panel.visible = true


func _show_credits() -> void:
	help_panel.visible = false
	credits_panel.visible = true


func _close_overlays() -> void:
	help_panel.visible = false
	credits_panel.visible = false


func _overlay_open() -> bool:
	return help_panel.visible or credits_panel.visible


func _sync_ui() -> void:
	splash_ui.visible = state == State.SPLASH
	intro_ui.visible = state == State.INTRO
	intro_ui.modulate.a = intro_alpha
	pause_ui.visible = state == State.PAUSED
	end_ui.visible = state == State.GAME_OVER or state == State.WIN
	restart_button.text = "Play Again" if state == State.WIN else "Restart"
	music_selector.select(gameplay_music_choice)

	for i in range(speed_buttons.size()):
		speed_buttons[i].button_pressed = i == speed_choice
		speed_buttons[i].icon = icon_check if i == speed_choice else icon_point


func _on_speed_button_pressed(index: int) -> void:
	speed_choice = index
	_sync_ui()
	queue_redraw()


func _on_volume_changed(value: float) -> void:
	music_volume = value
	_apply_audio()


func _on_music_selected(index: int) -> void:
	gameplay_music_choice = index
	if state == State.PAUSED:
		current_track = -1
		_update_music()


func _on_mute_toggled(pressed: bool) -> void:
	music_muted = pressed
	mute_button.text = "Muted" if pressed else "Mute"
	mute_button.icon = icon_cross if pressed else icon_line
	_apply_audio()


# ----- Screen / state changes ------------------------------------------------

func _start_game() -> void:
	state = State.PLAYING
	score = 0
	level = 1
	locks_since_ramp = 0
	gameplay_music_choice = randi() % GAMEPLAY_MUSIC_NAMES.size()
	current_fall_interval = SPEED_INTERVALS[speed_choice]
	fall_timer = 0.0
	soft_dropping = false
	_new_grid()
	_seed_targets(STARTING_TARGETS)
	_spawn_pair()
	_sync_ui()
	queue_redraw()
	_update_music()


func _set_paused(paused: bool) -> void:
	if paused:
		state = State.PAUSED
		soft_dropping = false
	else:
		state = State.PLAYING
	_sync_ui()
	queue_redraw()
	_update_music()


# ----- Targets ---------------------------------------------------------------

# Drop a number of target Blips into the lower part of the box. We avoid making
# a line of three same-color Blips at the start so nothing clears instantly.
func _seed_targets(count: int) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 1000:
		attempts += 1
		var c: int = randi() % COLS
		var r: int = TARGET_TOP_ROW + randi() % (ROWS - TARGET_TOP_ROW)
		if grid[r][c] != EMPTY:
			continue
		var color: int = randi() % BLIP_COLORS.size()
		if _would_make_triple(r, c, color):
			continue
		grid[r][c] = color
		targets[r][c] = true
		placed += 1


# Would placing this color here create a run of 3+ in a row or column?
func _would_make_triple(r: int, c: int, color: int) -> bool:
	var h: int = 1
	var x: int = c - 1
	while x >= 0 and grid[r][x] == color:
		h += 1
		x -= 1
	x = c + 1
	while x < COLS and grid[r][x] == color:
		h += 1
		x += 1
	if h >= 3:
		return true
	var v: int = 1
	var y: int = r - 1
	while y >= 0 and grid[y][c] == color:
		v += 1
		y -= 1
	y = r + 1
	while y < ROWS and grid[y][c] == color:
		v += 1
		y += 1
	return v >= 3


func _targets_remaining() -> int:
	var n: int = 0
	for r in range(ROWS):
		for c in range(COLS):
			if targets[r][c]:
				n += 1
	return n


# ----- The pair --------------------------------------------------------------

func _b_offset(orient: int) -> Vector2i:
	match orient:
		0: return Vector2i(1, 0)
		1: return Vector2i(0, -1)
		2: return Vector2i(-1, 0)
		3: return Vector2i(0, 1)
	return Vector2i(1, 0)


func _cell_b(a: Vector2i, orient: int) -> Vector2i:
	return a + _b_offset(orient)


func _is_free(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= COLS:
		return false
	if cell.y < 0 or cell.y >= ROWS:
		return false
	return grid[cell.y][cell.x] == EMPTY


func _can_place(a: Vector2i, orient: int) -> bool:
	return _is_free(a) and _is_free(_cell_b(a, orient))


func _spawn_pair() -> void:
	pair_cell_a = Vector2i(COLS / 2 - 1, 0)
	pair_orient = 0
	color_a = randi() % BLIP_COLORS.size()
	color_b = randi() % BLIP_COLORS.size()
	if not _can_place(pair_cell_a, pair_orient):
		state = State.GAME_OVER
		_play_sfx(sfx_fail)
		_sync_ui()


# ----- The game loop ---------------------------------------------------------

func _process(delta: float) -> void:
	anim_time += delta   # always advances, so the dancing text animates on every screen
	if not pop_effects.is_empty():
		var still: Array = []
		for fx in pop_effects:
			fx["t"] -= delta
			if fx["t"] > 0.0:
				still.append(fx)
		pop_effects = still
	if state == State.PLAYING:
		fall_timer += delta
		var interval: float = SOFT_DROP_INTERVAL if soft_dropping else current_fall_interval
		if fall_timer >= interval:
			fall_timer = 0.0
			_step_down()
		_update_music()
	queue_redraw()   # redraw every frame, on every screen, for the animation


func _step_down() -> void:
	var below: Vector2i = pair_cell_a + Vector2i(0, 1)
	if _can_place(below, pair_orient):
		pair_cell_a = below
	else:
		_lock_pair()


# Slam the pair straight down to where it would land, then lock it.
func _hard_drop() -> void:
	_play_sfx(sfx_drop)
	while _can_place(pair_cell_a + Vector2i(0, 1), pair_orient):
		pair_cell_a += Vector2i(0, 1)
	fall_timer = 0.0
	_lock_pair()


func _lock_pair() -> void:
	var a: Vector2i = pair_cell_a
	var b: Vector2i = _cell_b(pair_cell_a, pair_orient)
	grid[a.y][a.x] = color_a
	grid[b.y][b.x] = color_b
	_play_sfx(sfx_land)

	# Ramp the speed up a little every few locked pairs.
	locks_since_ramp += 1
	if locks_since_ramp >= RAMP_EVERY_LOCKS:
		locks_since_ramp = 0
		current_fall_interval = max(MIN_INTERVAL, current_fall_interval * RAMP_FACTOR)

	_resolve_board()
	if state == State.PLAYING:
		_spawn_pair()
	_update_music()


# Settle the board after a lock: let things fall, clear matches, repeat. Each
# loop is a deeper cascade and worth more. Win when every target is gone.
func _resolve_board() -> void:
	_apply_gravity()
	var chain: int = 0
	while true:
		var cells: Array = _find_matches()
		if cells.is_empty():
			break
		chain += 1
		if chain == 1:
			_play_sfx(sfx_match)
		for cell in cells:
			_add_pop(cell, grid[cell.y][cell.x])
			grid[cell.y][cell.x] = EMPTY
			targets[cell.y][cell.x] = false
		score += cells.size() * 10 * chain
		_apply_gravity()
	if _targets_remaining() == 0:
		state = State.WIN
		_play_sfx(sfx_win)
		_sync_ui()


# Per-column gravity. Target Blips are ANCHORED: they never fall. Only loose
# (non-target) Blips drop, and they stop on the floor, on a target, or on
# another settled Blip. We scan each column from the bottom up, keeping "write"
# pointed at the lowest open slot a falling Blip can land in.
func _apply_gravity() -> void:
	for c in range(COLS):
		var write: int = ROWS - 1
		for r in range(ROWS - 1, -1, -1):
			if targets[r][c]:
				# A target stays exactly where it is. Loose Blips above it must
				# come to rest on top of it, so the next open slot is just above.
				write = r - 1
			elif grid[r][c] != EMPTY:
				if write != r:
					grid[write][c] = grid[r][c]
					targets[write][c] = false
					grid[r][c] = EMPTY
				write -= 1


func _find_matches() -> Array:
	var mark: Array = []
	for r in range(ROWS):
		var row: Array = []
		for c in range(COLS):
			row.append(false)
		mark.append(row)

	# Horizontal runs.
	for r in range(ROWS):
		var c: int = 0
		while c < COLS:
			var val = grid[r][c]
			if val == EMPTY:
				c += 1
				continue
			var run: int = 1
			while c + run < COLS and grid[r][c + run] == val:
				run += 1
			if run >= MATCH_LEN:
				for k in range(run):
					mark[r][c + k] = true
			c += run

	# Vertical runs.
	for c in range(COLS):
		var r: int = 0
		while r < ROWS:
			var val = grid[r][c]
			if val == EMPTY:
				r += 1
				continue
			var run: int = 1
			while r + run < ROWS and grid[r + run][c] == val:
				run += 1
			if run >= MATCH_LEN:
				for k in range(run):
					mark[r + k][c] = true
			r += run

	var cells: Array = []
	for r in range(ROWS):
		for c in range(COLS):
			if mark[r][c]:
				cells.append(Vector2i(c, r))
	return cells


func _try_move(dx: int) -> void:
	var target: Vector2i = pair_cell_a + Vector2i(dx, 0)
	if _can_place(target, pair_orient):
		pair_cell_a = target


func _try_rotate(dir: int) -> void:
	var new_orient: int = (pair_orient + dir + 4) % 4
	if _can_place(pair_cell_a, new_orient):
		pair_orient = new_orient
		return
	for kick in [Vector2i(-1, 0), Vector2i(1, 0)]:
		var kicked: Vector2i = pair_cell_a + kick
		if _can_place(kicked, new_orient):
			pair_cell_a = kicked
			pair_orient = new_orient
			return


# ----- Input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if state == State.SPLASH or transition_active:
		return
	# An instructions/credits overlay swallows input; Esc or Backspace closes it.
	if _overlay_open():
		if event is InputEventKey and event.pressed and not event.echo:
			var oc: int = (event as InputEventKey).keycode
			if oc == KEY_ESCAPE or oc == KEY_BACKSPACE:
				_close_overlays()
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey

	if (key.keycode == KEY_DOWN or key.keycode == KEY_S) and state == State.PLAYING:
		if key.pressed and not key.echo:
			# A fresh Down tap. Two taps within DOUBLE_TAP_MS = hard drop.
			var t: int = Time.get_ticks_msec()
			if t - last_down_ms <= DOUBLE_TAP_MS:
				last_down_ms = -100000   # consume it so a third tap does not re-fire
				_hard_drop()
			else:
				last_down_ms = t
		soft_dropping = key.pressed
		return

	if not key.pressed:
		return

	match state:
		State.INTRO:
			if key.keycode == KEY_LEFT:
				speed_choice = max(0, speed_choice - 1)
				_sync_ui()
			elif key.keycode == KEY_RIGHT:
				speed_choice = min(SPEED_NAMES.size() - 1, speed_choice + 1)
				_sync_ui()
			else:
				_start_game()
		State.GAME_OVER:
			if key.keycode == KEY_R:
				_start_game()
		State.WIN:
			if key.keycode == KEY_R:
				_start_game()
		State.PAUSED:
			if key.keycode == KEY_P or key.keycode == KEY_ESCAPE:
				_set_paused(false)
		State.PLAYING:
			_handle_play_key(key)
	queue_redraw()
	_update_music()


func _handle_play_key(key: InputEventKey) -> void:
	if key.keycode == KEY_P or key.keycode == KEY_ESCAPE:
		_set_paused(true)
		return
	if key.keycode == KEY_R:
		_start_game()
		return
	match key.keycode:
		KEY_LEFT, KEY_A:
			_try_move(-1)
		KEY_RIGHT, KEY_D:
			_try_move(1)
		KEY_UP, KEY_W, KEY_X:
			if not key.echo:
				_try_rotate(1)
		KEY_Z:
			if not key.echo:
				_try_rotate(-1)


# ----- Drawing ---------------------------------------------------------------

func _draw() -> void:
	if state == State.SPLASH:
		return

	var board_size: Vector2 = Vector2(COLS * CELL, ROWS * CELL)

	draw_rect(Rect2(ORIGIN, board_size), Color(0.12, 0.12, 0.15))

	for c in range(COLS + 1):
		var x: float = ORIGIN.x + c * CELL
		draw_line(Vector2(x, ORIGIN.y), Vector2(x, ORIGIN.y + board_size.y), Color(1, 1, 1, 0.06))
	for r in range(ROWS + 1):
		var y: float = ORIGIN.y + r * CELL
		draw_line(Vector2(ORIGIN.x, y), Vector2(ORIGIN.x + board_size.x, y), Color(1, 1, 1, 0.06))

	if state != State.INTRO:
		for r in range(ROWS):
			for c in range(COLS):
				if grid[r][c] != EMPTY:
					_draw_blip(Vector2i(c, r), grid[r][c], targets[r][c])

	if state == State.PLAYING or state == State.PAUSED:
		_draw_blip(pair_cell_a, color_a, false)
		_draw_blip(_cell_b(pair_cell_a, pair_orient), color_b, false)

	_draw_pops()

	# The playfield frame (your LibreSprite art). Its transparent center sits over
	# the play area; drawn at ORIGIN minus the border so the opening lines up.
	if frame_tex != null:
		draw_texture(frame_tex, Vector2(ORIGIN.x - FRAME_BORDER, ORIGIN.y - FRAME_BORDER))
	else:
		draw_rect(Rect2(ORIGIN, board_size), Color(0.90, 0.90, 0.95), false, 2.0)

	if state != State.INTRO:
		_draw_hud(board_size)

	match state:
		State.INTRO:
			_draw_intro()
		State.PAUSED:
			_draw_overlay()
			_draw_dancing("PAUSED", ORIGIN.y + 150, 48, _title_font())
		State.GAME_OVER:
			_draw_overlay()
			_draw_dancing("GAME OVER", ORIGIN.y + board_size.y * 0.5 - 20, 44, _title_font())
			_draw_centered("press R", ORIGIN.y + board_size.y * 0.5 + 22, 22, Color(0.9, 0.9, 0.6))
		State.WIN:
			_draw_overlay()
			_draw_dancing("YOU WIN!", ORIGIN.y + board_size.y * 0.5 - 20, 46, _title_font())
			_draw_centered("press R", ORIGIN.y + board_size.y * 0.5 + 22, 22, Color(0.9, 0.9, 0.6))


func _draw_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_W, VIEW_H)), Color(0, 0, 0, 0.55))


func _draw_blip(cell: Vector2i, color_index: int, is_target: bool) -> void:
	var pos: Vector2 = ORIGIN + Vector2(cell.x * CELL, cell.y * CELL)
	# Use the real sprite if this color has art; targets use the "bad" Blip.
	var tex: Texture2D = blip_bad[color_index] if is_target else blip_idle[color_index]
	if tex != null:
		draw_texture(tex, pos)
		return
	# Fallback placeholder square (for colors that do not have art yet).
	var pad: float = 2.0
	var body: Rect2 = Rect2(pos + Vector2(pad, pad), Vector2(CELL - pad * 2.0, CELL - pad * 2.0))
	draw_rect(body, BLIP_COLORS[color_index])
	draw_rect(Rect2(pos + Vector2(6, 6), Vector2(5, 5)), Color(1, 1, 1, 0.5))
	if is_target:
		draw_rect(Rect2(pos + Vector2(8, 8), Vector2(CELL - 16, CELL - 16)), Color(0, 0, 0, 0.65), false, 2.0)


# Queue a pop effect at a cell when its Blip clears.
func _add_pop(cell: Vector2i, color_index: int) -> void:
	pop_effects.append({
		"pos": ORIGIN + Vector2(cell.x * CELL, cell.y * CELL),
		"color": color_index,
		"t": POP_TIME,
	})


# Draw the active pop effects: the surprised "pop" sprite if that color has art,
# otherwise a quick fading puff. Both fade out over POP_TIME.
func _draw_pops() -> void:
	for fx in pop_effects:
		var col: int = fx["color"]
		var fade: float = clamp(fx["t"] / POP_TIME, 0.0, 1.0)
		var tex: Texture2D = null
		if col >= 0 and col < blip_pop.size():
			tex = blip_pop[col]
		if tex != null:
			draw_texture(tex, fx["pos"], Color(1, 1, 1, fade))
		else:
			draw_rect(Rect2(fx["pos"] + Vector2(6, 6), Vector2(CELL - 12, CELL - 12)), Color(1, 1, 1, 0.6 * fade))


# Which font to use, with safe fallbacks to Godot's built-in font.
func _ui_font() -> Font:
	return font_ui if font_ui != null else ThemeDB.fallback_font


func _title_font() -> Font:
	if font_title != null:
		return font_title
	return _ui_font()


func _draw_hud(board_size: Vector2) -> void:
	var font: Font = _ui_font()
	var x: float = ORIGIN.x + board_size.x + 44
	draw_string(font, Vector2(x, 84), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.80, 0.80, 0.85))
	draw_string(font, Vector2(x, 112), str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, Vector2(x, 158), "LEVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.80, 0.80, 0.85))
	draw_string(font, Vector2(x, 186), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, Vector2(x, 232), "TARGETS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.80, 0.80, 0.85))
	draw_string(font, Vector2(x, 260), str(_targets_remaining()), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, Vector2(x, 306), "SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.80, 0.80, 0.85))
	draw_string(font, Vector2(x, 334), SPEED_NAMES[speed_choice], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


func _draw_intro() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIEW_W, VIEW_H)), Color(0, 0, 0, 0.55 * intro_alpha))
	_draw_dancing(TITLE, 210, 72, _title_font())
	_draw_centered(VERSION, 242, 20, _intro_color(Color(0.80, 0.80, 0.85)))
	_draw_centered(AUTHOR, 274, 20, _intro_color(Color(0.80, 0.80, 0.85)))
	_draw_centered("Choose a speed", 310, 20, _intro_color(Color(0.90, 0.90, 0.60)))


func _intro_color(color: Color) -> Color:
	return Color(color.r, color.g, color.b, color.a * intro_alpha)


func _draw_centered(text: String, y: float, size: int, color: Color, font: Font = null) -> void:
	var f: Font = font if font != null else _ui_font()
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, size, color)


# Draw text centered, with each letter bobbing in a wave and cycling through the
# Blip colors (Red / Green / Blue). Used for the title and the big banners.
func _draw_dancing(text: String, baseline_y: float, size: int, font: Font) -> void:
	var total_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = (VIEW_W - total_w) * 0.5
	for i in range(text.length()):
		var ch: String = text[i]
		var bob: float = sin(anim_time * DANCE_BOB_SPEED + i * DANCE_BOB_PHASE) * DANCE_BOB_AMP
		draw_string(font, Vector2(x, baseline_y + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _intro_color(_dance_color(i)) if state == State.INTRO else _dance_color(i))
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# Pick a Blip color for letter i, shifting over time so the colors travel along.
func _dance_color(i: int) -> Color:
	var idx: int = (i + int(anim_time * DANCE_COLOR_SPEED)) % BLIP_COLORS.size()
	return BLIP_COLORS[idx]
