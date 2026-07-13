extends SceneTree

const EXR_PATH := "res://assets/raw/terrain/motion_forge/Height_Map.exr"
const PNG_PATH := "res://assets/raw/terrain/motion_forge/Height_Map.png"

func _init() -> void:
	_introspect_terrain3d()
	_analyze()
	quit()

func _introspect_terrain3d() -> void:
	print("\n===== TERRAIN3D API =====")
	for cn in ["Terrain3D", "Terrain3DData"]:
		if not ClassDB.class_exists(cn):
			print(cn, ": (missing)"); continue
		print("--- ", cn, " methods (import/height/region) ---")
		for m in ClassDB.class_get_method_list(cn, true):
			var n: String = m.name
			if n.contains("import") or n.contains("height") or n.contains("region") or n.contains("save") or n.contains("directory"):
				var args := []
				for a in m.args: args.append("%s:%s" % [a.name, a.type])
				print("  ", n, "(", ", ".join(args), ")")

func _load_height() -> Image:
	var img := Image.new()
	var abs_exr := ProjectSettings.globalize_path(EXR_PATH)
	var err := img.load(abs_exr)
	if err == OK:
		print("loaded EXR: ", abs_exr, " format=", img.get_format())
		return img
	print("EXR load failed (err=%d), trying PNG" % err)
	var abs_png := ProjectSettings.globalize_path(PNG_PATH)
	err = img.load(abs_png)
	print("loaded PNG: err=", err, " format=", img.get_format())
	return img if err == OK else null

func _analyze() -> void:
	print("\n===== HEIGHTMAP ANALYSIS =====")
	var img := _load_height()
	if img == null:
		print("FAILED to load heightmap"); return
	var w := img.get_width(); var h := img.get_height()
	print("resolution: %dx%d  format=%d" % [w, h, img.get_format()])

	var vmin := INF; var vmax := -INF
	var step := 4  # sample every 4px for speed on 4096
	var buckets := 64
	var hist := PackedInt32Array(); hist.resize(buckets); hist.fill(0)
	var peak := Vector2i.ZERO
	for y in range(0, h, step):
		for x in range(0, w, step):
			var v := img.get_pixel(x, y).r
			if v < vmin: vmin = v
			if v > vmax:
				vmax = v; peak = Vector2i(x, y)
	var span: float = max(0.0001, vmax - vmin)
	# histogram pass
	for y in range(0, h, step):
		for x in range(0, w, step):
			var v := img.get_pixel(x, y).r
			var b := clampi(int((v - vmin) / span * (buckets - 1)), 0, buckets - 1)
			hist[b] += 1
	print("height value range (raw): min=%.5f  max=%.5f  span=%.5f" % [vmin, vmax, span])
	print("peak (highest) at pixel (%d,%d) = normalized (%.2f, %.2f)" % [peak.x, peak.y, float(peak.x)/w, float(peak.y)/h])

	# edge analysis (mean of each border, step sampled)
	var edges := {"top": [], "bottom": [], "left": [], "right": []}
	for x in range(0, w, step):
		edges["top"].append(img.get_pixel(x, 0).r)
		edges["bottom"].append(img.get_pixel(x, h-1).r)
	for y in range(0, h, step):
		edges["left"].append(img.get_pixel(0, y).r)
		edges["right"].append(img.get_pixel(w-1, y).r)
	for k in edges:
		var arr: Array = edges[k]
		var s := 0.0; var mn := INF; var mx := -INF
		for v in arr:
			s += v; mn = min(mn, v); mx = max(mx, v)
		print("edge %-6s mean=%.4f min=%.4f max=%.4f (norm within span: mean=%.2f)" % [k, s/arr.size(), mn, mx, (s/arr.size()-vmin)/span])

	# coarse 8x8 shape grid (normalized height per cell)
	print("--- coarse 8x8 height grid (normalized 0..1, row0=top/north) ---")
	var g := 8
	for gy in g:
		var line := ""
		for gx in g:
			var px := int((gx + 0.5) / g * w)
			var py := int((gy + 0.5) / g * h)
			var v := (img.get_pixel(px, py).r - vmin) / span
			line += "%4.2f " % v
		print("  ", line)

	# banding / stepping: count distinct quantized levels among sampled pixels
	var distinct := {}
	for y in range(0, h, step*2):
		for x in range(0, w, step*2):
			var q := int((img.get_pixel(x,y).r - vmin)/span * 1000.0)
			distinct[q] = true
	print("distinct quantized levels (x1000) among samples: ", distinct.size(), " (low => banding/stepping)")

	# histogram
	print("--- histogram (64 buckets, low->high) ---")
	var maxc := 1
	for c in hist: maxc = max(maxc, c)
	for i in range(buckets):
		if i % 2 == 0:
			var bar := "#".repeat(int(float(hist[i])/maxc*40))
			print("  %2d %s %d" % [i, bar, hist[i]])
