class_name MainPreparedCharacterAbility
extends RefCounted

var policy: MainCharacterAbilityPolicy
var command: Variant


func _init(p_policy: MainCharacterAbilityPolicy, p_command: Variant) -> void:
	policy = p_policy
	command = p_command
