class_name StructureModels
extends RefCounted
## Gray-box models for non-defense buildings. Each grows a little with level.


static func build(parent: Node3D, type: String, level: int, top: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = top
	var height := 3.0
	match type:
		"hq":
			height = _hq(root, level)
		"generator":
			height = _generator(root, level)
		"storage":
			height = _storage(root, level)
		"hangar":
			height = _hangar(root, level)
	level_label(root, level, height + 1.2)
	return root


static func level_label(parent: Node3D, level: int, y: float) -> Label3D:
	var label := Label3D.new()
	label.text = I18n.t("Lv %d") % level
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.pixel_size = 0.02
	label.outline_size = 14
	label.position = Vector3(0, y, 0)
	parent.add_child(label)
	return label


static func _hq(root: Node3D, level: int) -> float:
	var h := 2.5 + level * 0.9
	MeshKit.add(root, MeshKit.box(Vector3(3.4, h, 3.4)), MeshKit.mat(Color(0.32, 0.36, 0.42), 0.4, 0.5), Vector3(0, h / 2.0, 0))
	MeshKit.add(root, MeshKit.box(Vector3(3.5, 0.35, 3.5)), MeshKit.glow(Color(0.5, 0.9, 1.0)), Vector3(0, h * 0.62, 0))
	MeshKit.add(root, MeshKit.box(Vector3(3.7, 0.4, 3.7)), MeshKit.mat(Color(0.95, 0.75, 0.2), 0.3, 0.8), Vector3(0, h + 0.2, 0))
	MeshKit.add(root, MeshKit.cyl(0.08, 0.08, 3.0, 6), MeshKit.mat(Color(0.2, 0.2, 0.22), 0.5, 0.6), Vector3(0, h + 1.9, 0))
	MeshKit.add(root, MeshKit.sphere(0.18, 8), MeshKit.glow(Color(1.0, 0.25, 0.2)), Vector3(0, h + 3.4, 0))
	return h + 3.4


static func _generator(root: Node3D, level: int) -> float:
	var panel := MeshKit.mat(Color(0.1, 0.16, 0.3), 0.2, 0.4)
	var frame := MeshKit.mat(Color(0.75, 0.77, 0.8), 0.4, 0.7)
	var count := mini(level + 1, 4)
	for i in count:
		var x := -1.5 + (i % 2) * 3.0
		var z := -1.2 + int(i / 2.0) * 2.4
		MeshKit.add(root, MeshKit.box(Vector3(0.12, 0.8, 0.12)), frame, Vector3(x, 0.4, z))
		var p := MeshKit.add(root, MeshKit.box(Vector3(2.4, 0.08, 1.6)), panel, Vector3(x, 0.9, z))
		p.rotation.x = -0.5
	MeshKit.add(root, MeshKit.box(Vector3(0.8, 0.9, 0.6)), MeshKit.mat(Color(0.9, 0.9, 0.88), 0.6), Vector3(0, 0.45, 0))
	return 1.6


static func _storage(root: Node3D, level: int) -> float:
	var h := 1.6 + level * 0.5
	MeshKit.add(root, MeshKit.cyl(1.4, 1.4, h, 24), MeshKit.mat(Color(0.85, 0.88, 0.92), 0.35, 0.5), Vector3(0, h / 2.0, 0))
	MeshKit.add(root, MeshKit.cyl(1.45, 1.45, 0.3, 24), MeshKit.mat(Color(0.95, 0.75, 0.2), 0.3, 0.8), Vector3(0, h * 0.7, 0))
	var dome := MeshKit.add(root, MeshKit.sphere(1.4, 20), MeshKit.mat(Color(0.85, 0.88, 0.92), 0.35, 0.5), Vector3(0, h, 0))
	dome.scale = Vector3(1, 0.5, 1)
	return h + 0.7


static func _hangar(root: Node3D, level: int) -> float:
	var wall := MeshKit.mat(Color(0.78, 0.8, 0.82), 0.5, 0.4)
	var w := 3.0 + level * 0.3
	MeshKit.add(root, MeshKit.box(Vector3(w, 1.4, 2.6)), wall, Vector3(0, 0.7, 0))
	var roof := MeshKit.add(root, MeshKit.cyl(w / 2.0, w / 2.0, 2.6, 16), MeshKit.mat(Color(0.35, 0.45, 0.55), 0.4, 0.5), Vector3(0, 1.4, 0))
	roof.rotation.x = PI / 2.0
	roof.scale = Vector3(1, 1, 0.45)
	MeshKit.add(root, MeshKit.box(Vector3(w * 0.6, 1.1, 0.05)), MeshKit.mat(Color(0.12, 0.13, 0.15), 0.6), Vector3(0, 0.55, 1.31))
	return 2.2
