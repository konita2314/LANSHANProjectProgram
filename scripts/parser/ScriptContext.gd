## ScriptContext : RefCounted
## 运行时变量容器，提供 save / persist 两级作用域。
##
## save    — 存档内变量（随 SaveData 保存/恢复，不同存档独立）
## persist — 持久化变量（跨所有存档，由 GameManager 注入并持久化到独立配置）
## 查找时先 save 后 persist；@set 写入 save，@persist 写入 persist。
class_name ScriptContext extends RefCounted

var _save_vars: Dictionary = {}
var _persist_vars: Dictionary = {}

## GameManager 注入的回调：当 persist 变量被写入时触发。
## 签名：(name: String, value: Variant) -> void
var persist_var_set: Callable


func _init() -> void:
	persist_var_set = _noop_persist_callback


func _noop_persist_callback(_name: String, _value: Variant) -> void:
	pass


## 获取变量值 — 先查 save，再查 persist，都不存在返回 0。
func get_var(name: String) -> Variant:
	if _save_vars.has(name):
		return _save_vars[name]
	if _persist_vars.has(name):
		return _persist_vars[name]
	return 0


## 直接写入 save 作用域。
func set_var(name: String, value: Variant) -> void:
	_save_vars[name] = value


## GameManager 在 VN 启动前注入已持久化的变量。
func set_persist_vars(dict: Dictionary) -> void:
	_persist_vars = dict.duplicate()


## 解析并执行赋值表达式，如 "affection += 10" 或 "flag = true"。
## is_persist = false → 写入 save 作用域（存档内，@set）
## is_persist = true  → 写入 persist 作用域（跨存档，@persist）
func apply_expression(expr: String, is_persist: bool = false) -> void:
	if expr.is_empty():
		return

	# 解析 var op value 格式
	var parsed: Dictionary = _parse_assignment(expr)
	if parsed.is_empty():
		push_warning("ScriptContext: cannot parse expression — ", expr)
		return

	var var_name: String = parsed["var"]
	var op: String = parsed["op"]
	var value_expr: String = parsed["value"]

	# 求值右侧表达式
	var rhs: Variant = ScriptExpression.evaluate(value_expr, self)

	# 根据作用域选存储位置
	var target: Dictionary = _persist_vars if is_persist else _save_vars
	var current: Variant = target.get(var_name, 0) if op != "=" else 0

	# 应用运算符
	var result: Variant
	match op:
		"=":
			result = rhs
			target[var_name] = result
		"+=", "-=", "*=", "/=":
			match op:
				"+=": result = current + rhs
				"-=": result = current - rhs
				"*=": result = current * rhs
				"/=": result = current / rhs
			target[var_name] = result
		_:
			push_warning("ScriptContext: unknown operator ", op, " in — ", expr)
			return

	# 若为 persist 写入，通知 GameManager 持久化 + 触发桥接
	if is_persist:
		persist_var_set.call(var_name, result)


## 解析 "var op value" 为 { var, op, value } 字典。
func _parse_assignment(expr: String) -> Dictionary:
	# 支持的运算符（按长度降序，避免 += 被误匹配为 =）
	var ops: Array[String] = ["+=", "-=", "*=", "/=", "="]
	for op_str: String in ops:
		var op_idx: int = expr.find(op_str)
		if op_idx > 0:
			var var_name: String = expr.substr(0, op_idx).strip_edges()
			var value_expr: String = expr.substr(op_idx + op_str.length()).strip_edges()
			return {"var": var_name, "op": op_str, "value": value_expr}
	return {}


## 序列化 save 变量为存档格式（persist 变量由 GameManager 独立管理）。
func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for key: String in _save_vars:
		if not key.begins_with("__temp_"):
			d[key] = _save_vars[key]
	return d


## 从存档恢复 save 变量。
func from_dict(d: Dictionary) -> void:
	_save_vars = d.duplicate() if not d.is_empty() else {}
