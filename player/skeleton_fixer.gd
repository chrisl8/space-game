# https://github.com/godotengine/godot/issues/73888#issuecomment-1768236299

@tool
extends Skeleton2D

@export var apply_all_local = false:
	set(val):
		apply_all_local = val
		_apply_all_skeleton_modifier_set_local_to_scene(get_modification_stack(), val, 0)


func _apply_all_skeleton_modifier_set_local_to_scene(
	stack: SkeletonModificationStack2D, boo: bool, level: int
):
	var indent = ""
	for k in range(0, level):
		indent += "  "

	if !stack:
		print("%sStack empty" % [indent])
		return

	stack.resource_local_to_scene = boo
	print("%sSetting stack %s -> resource_local_to_scene = %s " % [indent, stack, boo])

	for idx in range(0, stack.modification_count):
		var modification: SkeletonModification2D = stack.get_modification(idx)
		modification.resource_local_to_scene = boo
		print("%sSetting modifier %s -> resource_local_to_scene = %s " % [indent, stack, boo])

		if modification is SkeletonModification2DStackHolder:
			_apply_all_skeleton_modifier_set_local_to_scene(
				(modification as SkeletonModification2DStackHolder).get_held_modification_stack(),
				boo,
				level + 1
			)

	print("%sSetting stack %s -> done" % [indent, stack])
