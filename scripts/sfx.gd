extends Node
## Sons générés au démarrage : aucune musique sous droits.
## - Cloches douces sur une gamme pentatonique (toujours harmonieuses).
## - Chaque rebond joue la note suivante d'une mélodie originale : la partie « compose ».
## - Fusions : arpège qui monte avec le combo ; forme finale : grand accord.
## - Nappe d'ambiance discrète en boucle.

const RATE := 32000
## Mélodie originale (indices dans la gamme), jouée note par note à chaque rebond.
const MELODY := [7, 9, 10, 9, 7, 5, 7, 4, 5, 7, 9, 7, 5, 4, 2, 4,
	5, 7, 9, 12, 11, 9, 7, 9, 10, 9, 7, 5, 4, 5, 7, 5,
	2, 4, 5, 7, 9, 7, 5, 4, 5, 4, 2, 0, 2, 4, 5, 4]
## Gamme pentatonique majeure sur trois octaves (demi-tons depuis la note de base).
const SCALE := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31, 33]
const BASE_HZ := 261.63  # do

var _bells: Array[AudioStreamWAV] = []
var _thump: AudioStreamWAV
var _swell: AudioStreamWAV
var _pad: AudioStreamWAV
var _meow: AudioStreamWAV
var _mrrp: AudioStreamWAV
var _purr: AudioStream
## Vrais miaous (audio/miaou_1.ogg, miaou_2.ogg…) s'ils existent ; sinon miaou synthétique.
var _meows: Array[AudioStream] = []
var _players: Array[AudioStreamPlayer] = []
var _pad_player: AudioStreamPlayer
var _melody_i := 0
var _last_note_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for semi in SCALE:
		_bells.append(_bell(BASE_HZ * pow(2.0, semi / 12.0)))
	_thump = _make_thump()
	_swell = _make_swell()
	_pad = _make_pad()
	_meow = _make_meow()
	_mrrp = _make_mrrp()
	_purr = _load_loop("res://audio/ronron.ogg")
	if _purr == null:
		_purr = _make_purr()
	for i in range(1, 9):
		var path := "res://audio/miaou_%d.ogg" % i
		if ResourceLoader.exists(path):
			_meows.append(load(path))
	_pad_player = AudioStreamPlayer.new()
	_pad_player.stream = _pad
	_pad_player.volume_db = -20.0
	add_child(_pad_player)


## Nappe d'ambiance ; dans l'univers Chats, un ronronnement à la place.
func start_ambience() -> void:
	var want: AudioStream = _purr if Save.universe == "chats" else _pad
	if _pad_player.stream != want:
		_pad_player.stop()
		_pad_player.stream = want
		_pad_player.volume_db = -10.0 if want == _purr else -20.0
	if Save.sound and not _pad_player.playing:
		_pad_player.play()


func _play(stream: AudioStream, db: float, pitch := 1.0) -> void:
	if not Save.sound:
		return
	var best: AudioStreamPlayer = _players[0]
	for p in _players:
		if not p.playing:
			best = p
			break
	best.stream = stream
	best.volume_db = db
	best.pitch_scale = pitch
	best.play()


## Rebond : la note suivante de la mélodie, plus forte si le choc est fort.
func bounce(strength: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_note_ms < 70:
		return
	_last_note_ms = now
	var idx: int = MELODY[_melody_i % MELODY.size()]
	_melody_i += 1
	if Save.universe == "chats":
		# Petit « mrrp » de chat, sur la même mélodie.
		var semi: int = SCALE[clampi(idx, 0, SCALE.size() - 1)]
		_play(_mrrp, lerpf(-20.0, -9.0, clampf(strength, 0.0, 1.0)), pow(2.0, (semi - 9) / 12.0))
		return
	_play(_bells[clampi(idx, 0, _bells.size() - 1)], lerpf(-16.0, -5.0, clampf(strength, 0.0, 1.0)))


## Fusion : arpège ascendant, plus aigu avec le niveau et le combo.
func merge(tier: int, combo: int) -> void:
	var root := clampi(tier % 5 + mini(combo, 5), 0, _bells.size() - 5)
	_play(_thump, -8.0, 1.0 + tier * 0.03)
	if Save.universe == "chats":
		return
	for k in 3:
		get_tree().create_timer(0.055 * k).timeout.connect(_play.bind(_bells[mini(root + k * 2, _bells.size() - 1)], -6.0 - k))


func final_form() -> void:
	_play(_swell, -3.0)
	if Save.universe == "chats":
		# Un miaou géant, puis une réponse de petits chatons.
		meow(10)
		for k in 3:
			get_tree().create_timer(1.1 + 0.18 * k).timeout.connect(meow.bind(k))
		return
	for k in 6:
		get_tree().create_timer(0.09 * k).timeout.connect(_play.bind(_bells[mini(5 + k * 2, _bells.size() - 1)], -4.0))


func lose() -> void:
	for k in 4:
		get_tree().create_timer(0.14 * k).timeout.connect(_play.bind(_bells[maxi(6 - k * 2, 0)], -7.0, 0.5))


## Miaou (univers Chats). Plus le chat est gros, plus c'est grave et lent,
## jusqu'à devenir absurdement énorme pour le Roi des chats et le Chat cosmique.
func meow(tier: int) -> void:
	var u := tier / 10.0
	var pitch := 1.6 * pow(0.2, pow(u, 1.3))  # 1,6 (chaton) → 0,32 (chat cosmique)
	var db := lerpf(-9.0, 0.0, u)
	var s: AudioStream = _meow
	if not _meows.is_empty():
		s = _meows[clampi(int(u * _meows.size()), 0, _meows.size() - 1)] if tier < 9 else _meows.pick_random()
	_play(s, db, pitch * randf_range(0.96, 1.04))


func _load_loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	return st


func tick() -> void:
	_play(_bells[10], -18.0, 1.5)


# --- Synthèse ---

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


## Cloche / marimba : fondamentale + harmoniques inharmoniques, attaque douce, longue décroissance.
func _bell(hz: float) -> AudioStreamWAV:
	var n := int(RATE * 1.4)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var att := minf(1.0, t / 0.004)
		var v := sin(TAU * hz * t) * exp(-t * 3.2)
		v += 0.35 * sin(TAU * hz * 2.0 * t) * exp(-t * 5.5)
		v += 0.18 * sin(TAU * hz * 3.01 * t) * exp(-t * 9.0)
		v += 0.10 * sin(TAU * hz * 4.2 * t) * exp(-t * 14.0)
		s[i] = v * att * 0.42
	return _wav(s)


func _make_thump() -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var hz := lerpf(180.0, 55.0, minf(1.0, t / 0.18))
		ph += TAU * hz / RATE
		s[i] = sin(ph) * exp(-t * 11.0) * 0.8
	return _wav(s)


func _make_swell() -> AudioStreamWAV:
	var n := int(RATE * 2.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := sin(minf(t / 2.6, 1.0) * PI)
		lp += 0.08 * ((randf() * 2.0 - 1.0) - lp)
		var tone := 0.0
		for h in [1.0, 1.5, 2.0, 2.5, 3.0]:
			tone += sin(TAU * 130.81 * h * t) / h
		s[i] = (tone * 0.22 + lp * 0.5) * env * 0.7
	return _wav(s)


## Nappe : deux accords lents, légèrement désaccordés, en boucle de 8 s.
func _make_pad() -> AudioStreamWAV:
	var dur := 8.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var chords := [[130.81, 196.0, 329.63], [110.0, 164.81, 261.63]]
	for i in n:
		var t := float(i) / RATE
		var half := 0 if t < dur * 0.5 else 1
		var local := fmod(t, dur * 0.5) / (dur * 0.5)
		var env := sin(local * PI)
		var v := 0.0
		for f in chords[half]:
			v += sin(TAU * f * t) + 0.6 * sin(TAU * f * 1.003 * t)
		s[i] = v * env * 0.06
	return _wav(s, true)


## Miaou synthétique par formants : la voix passe de « i » à « a » à « ou » (mi-a-ou),
## hauteur qui monte puis retombe, léger vibrato et souffle. Remplacé par de vrais
## enregistrements si audio/miaou_N.ogg existent.
func _make_meow() -> AudioStreamWAV:
	var dur := 0.62
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var noise := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		var f0 := 560.0 + 260.0 * sin(minf(u * 1.5, 1.0) * PI * 0.9) - 160.0 * u * u
		f0 *= 1.0 + 0.012 * sin(TAU * 6.0 * t)
		ph += TAU * f0 / RATE
		# Trajectoire des formants : i (début) → a (milieu) → ou (fin).
		var a1 := smoothstep(0.0, 0.35, u)
		var a2 := smoothstep(0.55, 1.0, u)
		var F1 := lerpf(lerpf(420.0, 950.0, a1), 520.0, a2)
		var F2 := lerpf(lerpf(2300.0, 1500.0, a1), 950.0, a2)
		var v := 0.0
		var h := 1
		while h * f0 < 7000.0:
			var fh := h * f0
			var g := exp(-pow((fh - F1) / 260.0, 2.0)) + 0.7 * exp(-pow((fh - F2) / 340.0, 2.0)) + 0.18 * exp(-pow((fh - 3300.0) / 500.0, 2.0))
			v += sin(ph * h) * g / sqrt(float(h))
			h += 1
		noise += 0.3 * ((randf() * 2.0 - 1.0) - noise)
		var env := smoothstep(0.0, 0.06, u) * pow(1.0 - u, 1.2)
		s[i] = (v * 0.42 + noise * 0.05 * (0.3 + a1)) * env
	return _wav(s)


## « Mrrp » : petit trille de chat (son roulé, hauteur qui monte), très court.
func _make_mrrp() -> AudioStreamWAV:
	var dur := 0.2
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		ph += TAU * (380.0 + 260.0 * u) / RATE
		var tone := sin(ph) + 0.5 * sin(ph * 2.0) + 0.25 * sin(ph * 3.0)
		var roll := 0.55 + 0.45 * sin(TAU * 34.0 * t)
		lp += 0.25 * (tone - lp)
		var env := minf(1.0, t / 0.012) * pow(1.0 - u, 1.4)
		s[i] = lp * roll * env * 0.5
	return _wav(s)


## Ronronnement en boucle : souffle grave pulsé ~25 fois par seconde, inspire / expire.
func _make_purr() -> AudioStreamWAV:
	var dur := 3.2
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var breath := 0.6 + 0.4 * sin(TAU * t / dur * 2.0)  # deux respirations par boucle
		var rate := 24.0 if fmod(t, dur * 0.5) < dur * 0.28 else 27.0
		var pulse := pow(maxf(0.0, sin(TAU * rate * t)), 3.0)
		lp += 0.05 * ((randf() * 2.0 - 1.0) - lp)
		lp2 += 0.1 * (lp - lp2)
		var body := sin(TAU * 52.0 * t) * 0.4 + lp2 * 3.0
		s[i] = body * pulse * breath * 0.5
	return _wav(s, true)
