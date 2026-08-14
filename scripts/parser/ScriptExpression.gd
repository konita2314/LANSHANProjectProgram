## ScriptExpression : RefCounted
## 对 Godot 内置 Expression 类的轻量封装。
##
## 自动从表达式字符串中提取变量名，从 ScriptContext 取值，
## 调用 Expression.execute() 完成求值。
## 所有方法均为 static — 无需实例化。
class_name ScriptExpression extends RefCounted

# GDScript 关键字 / 字面量 — 从变量名提取中排除
const KEYWORDS: Array[String] = [
	"and", "or", "not", "true", "false", "null",
	"if", "else", "elif", "endif", "for", "while", "break", "continue",
	"return", "match", "when", "pass", "in", "is", "as", "self",
	"PI", "TAU", "INF", "NAN",
]

## 求值表达式，返回 Variant（bool / int / float / String）。
## context 提供变量值。
static func evaluate(expr: String, context: ScriptContext) -> Variant:
	if expr.is_empty():
		return false

	# 1. 提取变量名
	var var_names: Array[String] = _extract_variables(expr)

	# 2. 构建 Godot Expression
	var ge := Expression.new()
	var error: Error = ge.parse(expr, var_names)
	if error != OK:
		push_warning("ScriptExpression: parse error at — ", expr, " (", ge.get_error_text(), ")")
		return false

	# 3. 从 context 收集变量值
	var values: Array = []
	for vn: String in var_names:
		values.append(context.get_var(vn))

	# 4. 执行
	var result: Variant = ge.execute(values, null)
	if ge.has_execute_failed():
		push_warning("ScriptExpression: execute error — ", expr, " (", ge.get_error_text(), ")")
		return false

	return result


## 从表达式字符串中提取变量名，过滤关键字和纯数字。
static func _extract_variables(expr: String) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	var ident_regex := RegEx.new()
	ident_regex.compile("[a-zA-Z_][a-zA-Z0-9_]*")

	for m in ident_regex.search_all(expr):
		var name: String = m.get_string()
		# 跳过关键字
		if name.to_lower() in KEYWORDS:
			continue
		# 去重（保持出现顺序）
		if not seen.has(name):
			seen[name] = true
			result.append(name)

	return result
