extends Node

const MIX_RATE := 22050.0

func blip(freq: float, duration: float, volume: float) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = maxf(0.25, duration + 0.1)

	var player := AudioStreamPlayer.new()
	player.stream = gen
	add_child(player)
	player.play()

	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb != null:
		var frames := int(duration * MIX_RATE)
		var period := MIX_RATE / maxf(freq, 1.0)
		var fade := maxf(1.0, MIX_RATE * 0.006)
		for i in range(frames):
			if pb.get_frames_available() <= 0:
				break
			var phase := fmod(float(i), period) / period
			var s: float = volume if phase < 0.5 else -volume
			if i > frames - fade:
				s *= float(frames - i) / fade
			pb.push_frame(Vector2(s, s))

	await get_tree().create_timer(duration + 0.2).timeout
	player.queue_free()

# --- Named events (GDD §11) ----------------------------------------------

func send() -> void:
	blip(880.0, 0.05, 0.18)

func receive() -> void:
	blip(660.0, 0.06, 0.28)

func send_fail() -> void:
	blip(220.0, 0.18, 0.32)

func digit_drop() -> void:
	blip(330.0, 0.12, 0.30)

func low_power() -> void:
	blip(300.0, 0.1, 0.30)
	await get_tree().create_timer(0.1).timeout
	blip(250.0, 0.1, 0.30)

func phone_dies() -> void:
	blip(425.0, 0.9, 0.32)
