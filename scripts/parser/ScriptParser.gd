## ScriptParser : RefCounted
## 将 .gd 剧本字符串解析为 PlotData 资源。
##
## 语法规则见 .claude/script.md。
##
## V2 新增：
##   @label / @goto  — 锚点跳转
##   @set var op expr — 存档作用域变量赋值
##   @persist var op expr — 持久化作用域变量赋值
##   @if / @else / @endif — 条件分支（支持嵌套）
##   行号错误定位
##   选项 actions 表达式
class_name ScriptParser extends RefCounted

var _plot_id: String = ""
var _title: LocText = null
var _characters: Dictionary = {}

const CMD_REGEX: String = "@(\\w+)\\s*(.*)"
const OPT_TARGET_REGEX: String = "(.+?)\\s*->\\s*(.+)"
const META_ID_REGEX: String = "::\\s*(\\w+)\\s*$"

# 不进入 cond_stack 内（即不被收集为 then/else 体）的流程指令
const FLOW_COMMANDS: Array[String] = ["if", "else", "endif", "label", "goto", "set", "persist"]


func _init(plot_id: String = "") -> void:
	_plot_id = plot_id
	_title = LocText.new()
	_title.ZH = "新剧本"
	_title.EN = "New Script"


# ═══════════════════════════════════════════════════════════════
# 顶层解析入口
# ═══════════════════════════════════════════════════════════════

func parse(raw: String) -> PlotData:
	var lines: Array[String] = _preprocess(raw)
	var nodes: Array[PlotNode] = []
	var cond_stack: Array[Dictionary] = []   # [{if_node, if_idx, else_idx}]
	var last_who: String = ""
	var i: int = 0

	while i < lines.size():
		var stripped: String = lines[i].strip_edges()
		var line_no: int = i + 1   # 1-based 行号

		# ── 流程指令（label / goto / set / if / else / endif）──
		if stripped.begins_with("@"):
			var cmd_match := RegEx.create_from_string(CMD_REGEX).search(stripped)
			if cmd_match:
				var cmd: String = cmd_match.get_string(1).to_lower()
				if cmd in FLOW_COMMANDS:
					var raw_args: String = cmd_match.get_string(2).strip_edges()
					_parse_flow_directive(cmd, raw_args, nodes, cond_stack, line_no)
					i += 1
					continue

		# ── 常规指令（@bg / @bgm / @sfx 等）──
		if stripped.begins_with("@"):
			var node: PlotNode = _parse_directive(stripped, line_no)
			if node:
				_append_node(nodes, cond_stack, node)
			i += 1
			continue

		# ── 选项 ──
		if stripped.begins_with("-"):
			var sel_node: PlotNode = _ensure_select_node(nodes, cond_stack)
			var opt: PlotOption = _parse_option(stripped)
			sel_node.options.append(opt)
			i += 1
			var rb: Array = _parse_reactions(lines, i, cond_stack)
			opt.reaction_nodes = rb[0]
			i = rb[1]
			continue

		# ── 对话或旁白 ──
		var result: Dictionary = _parse_dialogue(stripped, last_who, line_no)
		_append_node(nodes, cond_stack, result["node"])
		last_who = result["last_who"]
		i += 1

	# ── 检查未闭合的 @if ──
	if not cond_stack.is_empty():
		for entry: Dictionary in cond_stack:
			push_error("ScriptParser: unclosed @if at node ", entry["if_idx"],
				" (line ", entry["if_node"].line_number, ")")

	# ── 二次解析：@goto 标签决议 ──
	var data := PlotData.new()
	data.id = _plot_id
	data.title = _title
	data.characters = _characters
	data.nodes = nodes

	# 收集所有 label → node_index
	for ni: int in range(nodes.size()):
		var n: PlotNode = nodes[ni]
		if n.type == "label" and not n.label.is_empty():
			if data.labels.has(n.label):
				push_warning("ScriptParser: duplicate label '", n.label, "' at line ", n.line_number)
			data.labels[n.label] = ni

	# 决议 goto
	for ni: int in range(nodes.size()):
		var n: PlotNode = nodes[ni]
		if n.type == "goto":
			if data.labels.has(n.goto_label):
				n.jump_to = data.labels[n.goto_label]
			else:
				push_error("ScriptParser: @goto '", n.goto_label, "' target not found (line ", n.line_number, ")")

	return data


# ═══════════════════════════════════════════════════════════════
# 预处理
# ═══════════════════════════════════════════════════════════════

func _preprocess(raw: String) -> Array[String]:
	var result: Array[String] = []
	for line in raw.split("\n"):
		var stripped := line.strip_edges(false, true)
		if stripped.is_empty(): continue
		if stripped.begins_with("#"): continue
		if stripped.strip_edges().begins_with("::"):
			_parse_meta(stripped.strip_edges())
			continue
		result.append(stripped)
	return result


func _parse_meta(line: String) -> void:
	if not line.begins_with("::"): return
	var id_match := RegEx.create_from_string(META_ID_REGEX).search(line)
	if id_match: _plot_id = id_match.get_string(1); return
	var stripped := line.trim_prefix("::").strip_edges()
	if stripped.begins_with("title "):
		_title.ZH = stripped.trim_prefix("title ").strip_edges()
	elif stripped.begins_with("id "):
		_plot_id = stripped.trim_prefix("id ").strip_edges()


# ═══════════════════════════════════════════════════════════════
# 流程指令解析（V2 新增）
# ═══════════════════════════════════════════════════════════════

## 处理 @label / @goto / @set / @if / @else / @endif
func _parse_flow_directive(cmd: String, raw_args: String, nodes: Array[PlotNode], cond_stack: Array[Dictionary], line_no: int) -> void:
	match cmd:
		"label":
			var node := _make_node("label", line_no)
			node.label = raw_args
			_append_node(nodes, cond_stack, node)

		"goto":
			var node := _make_node("goto", line_no)
			node.goto_label = raw_args
			# jump_to 在二次解析中填入
			_append_node(nodes, cond_stack, node)

		"set":
			var node := _make_node("set", line_no)
			node.expression = raw_args
			_append_node(nodes, cond_stack, node)

		"persist":
			# type "persist" — 运行时写持久化作用域（跨存档全局）
			var node := _make_node("persist", line_no)
			node.expression = raw_args
			_append_node(nodes, cond_stack, node)

		"if":
			var node := _make_node("if", line_no)
			node.expression = raw_args
			# jump_to 在 @else / @endif 时回填
			var idx: int = _append_node(nodes, cond_stack, node)
			cond_stack.append({"if_node": node, "if_idx": idx, "else_idx": -1})

		"else":
			if cond_stack.is_empty():
				push_error("ScriptParser: @else without matching @if (line ", line_no, ")")
				return
			var top: Dictionary = cond_stack[cond_stack.size() - 1]
			if top["else_idx"] >= 0:
				push_error("ScriptParser: duplicate @else for @if at line ", top["if_node"].line_number)
				return
			var node := _make_node("else", line_no)
			# jump_to 在 @endif 时回填
			var idx: int = _append_node(nodes, cond_stack, node)
			top["else_idx"] = idx

		"endif":
			if cond_stack.is_empty():
				push_error("ScriptParser: @endif without matching @if (line ", line_no, ")")
				return
			var top: Dictionary = cond_stack.pop_back()
			var endif_idx: int = nodes.size()
			var node := _make_node("endif", line_no)
			_append_node_raw(nodes, node)

			var if_node: PlotNode = top["if_node"]
			var else_idx: int = top["else_idx"]

			if else_idx >= 0:
				# 有 @else：@if 的 jump_to = else 体的第一个节点（else_idx + 1）
				if_node.jump_to = else_idx + 1
				# @else 的 jump_to = endif
				nodes[else_idx].jump_to = endif_idx
			else:
				# 无 @else：@if 的 jump_to = endif
				if_node.jump_to = endif_idx

		_:
			push_warning("ScriptParser: unknown flow directive @", cmd, " (line ", line_no, ")")


# ═══════════════════════════════════════════════════════════════
# 常规指令解析
# ═══════════════════════════════════════════════════════════════

func _parse_directive(line: String, line_no: int = 0) -> PlotNode:
	var cmd_match := RegEx.create_from_string(CMD_REGEX).search(line)
	if not cmd_match:
		push_warning("ScriptParser: malformed directive — ", line)
		return null

	var cmd: String = cmd_match.get_string(1).to_lower()
	var raw_args: String = cmd_match.get_string(2).strip_edges()
	# 去掉旧格式遗留的外层括号：@bg(path) → path
	if raw_args.begins_with("(") and raw_args.ends_with(")"):
		raw_args = raw_args.substr(1, raw_args.length() - 2).strip_edges()
	var args: Array[String] = _split_args(raw_args)
	# 每个参数也去掉可能的外层括号
	for a_idx: int in range(args.size()):
		var a: String = args[a_idx]
		if a.begins_with("(") and a.ends_with(")"):
			args[a_idx] = a.substr(1, a.length() - 2).strip_edges()

	var node := _make_node("scene", line_no)
	node.ZH = ""; node.EN = ""

	match cmd:
		"bg":
			if args.size() > 0:
				var first: String = args[0]
				if first == "up":
					node.bg_align = "up"
				elif first == "down":
					node.bg_align = "down"
				else:
					node.bg = AssetResolver.resolve_bg(first)
					if args.size() > 1:
						var second: String = args[1]
						if second == "up": node.bg_align = "up"
						elif second == "down": node.bg_align = "down"
		"bgm":          _parse_bgm(node, args, line_no)
		"sfx":          _parse_sfx(node, args, line_no)
		"ambience":     _parse_ambience(node, args, line_no)
		"stopaudio":    _build_stop_audio(node)
		"ch":           _parse_ch(node, args)
		"glitch":
			node.glitch = not (args.size() > 0 and args[0] == "off")
		"wait":
			if args.size() > 0 and args[0].is_valid_float():
				node.wait_time = args[0].to_float()
		"stop":         node.stop_transition = true
		"black":
			node.fade_black = args[0].to_float() if args.size() > 0 and args[0].is_valid_float() else 1.0
		"jump":
			if args.size() > 0:
				var target: String = args[0]
				if target.begins_with("scene:"):
					node.next_scene = target.trim_prefix("scene:").to_upper()
					# @jump scene:CALENDAR 11-1 — 携带日期参数
					if args.size() > 1:
						node.jump_date = args[1]
				else:
					node.jump_plot_id = target
					node.jump_node_index = 0
		"settime":
			if args.size() > 0:
				node.expression = args[0]   # "11-1"
				node.next_scene = "DATESWITCH"
		"timeset":
			if args.size() > 0:
				node.expression = args[0]   # "22-8-28"
				node.next_scene = "DATESWITCH"
		"sidesettime":
			if args.size() > 0:
				node.expression = args[0]
				node.next_scene = "DATESWITCH"
				node.note = "side"
		"sidetimeset":
			if args.size() > 0:
				node.expression = args[0]
				node.next_scene = "DATESWITCH"
				node.note = "side"
		"title":        node.back_to_title = true
		"rechoose":     node.rechoose = true
		"end":          node.end_story = true
		_:
			push_warning("ScriptParser: unknown directive @", cmd, " — skipped (line ", line_no, ")")

	return node


func _parse_bgm(node: PlotNode, args: Array[String], line_no: int = 0) -> void:
	if args.is_empty():
		push_warning("ScriptParser: @bgm missing argument (line ", line_no, ")")
		return
	var sub: String = args[0].to_lower()
	var c := AudioCommand.new(); c.loop = true; c.audio_type = "bgm"
	if sub == "fadeout":
		c.stop = true; c.fade_out_only = true
		c.fade_out_duration = args[1].to_float() if args.size() > 1 and args[1].is_valid_float() else 2.0
	elif sub == "crossfade" and args.size() > 1:
		c.play = AssetResolver.resolve_music(args[1]); c.crossfade = true
		c.fade_out_duration = args[2].to_float() if args.size() > 2 and args[2].is_valid_float() else 1.5
		c.fade_in_duration = args[3].to_float() if args.size() > 3 and args[3].is_valid_float() else c.fade_out_duration
	else:
		c.play = AssetResolver.resolve_music(args[0])
	node.bgm = c


func _parse_sfx(node: PlotNode, args: Array[String], line_no: int = 0) -> void:
	if args.is_empty() or args[0].is_empty():
		push_warning("ScriptParser: @sfx missing argument (line ", line_no, ")")
		return
	var c := AudioCommand.new(); c.play = AssetResolver.resolve_sfx(args[0]); c.audio_type = "sfx_short"
	node.sfx_short = c


func _parse_ambience(node: PlotNode, args: Array[String], line_no: int = 0) -> void:
	if args.is_empty() or args[0].is_empty():
		push_warning("ScriptParser: @ambience missing argument (line ", line_no, ")")
		return
	var c := AudioCommand.new()
	c.play = AssetResolver.resolve_ambience(args[0]); c.loop = true; c.audio_type = "ambience"
	c.ambience_volume = args[1].to_float() if args.size() > 1 and args[1].is_valid_float() else 0.5
	node.ambience = c


func _build_stop_audio(node: PlotNode) -> void:
	var a := AudioCommand.new(); a.stop = true; node.bgm = a
	var b := AudioCommand.new(); b.stop = true; node.sfx_short = b
	var c := AudioCommand.new(); c.stop = true; node.ambience = c


func _parse_ch(node: PlotNode, args: Array[String]) -> void:
	if args.is_empty(): return
	if args[0] == "clear": node.ch = "__CLEAR__"
	else: node.ch = AssetResolver.resolve_ch(args[0])


# ═══════════════════════════════════════════════════════════════
# 对话解析
# ═══════════════════════════════════════════════════════════════

func _parse_dialogue(line: String, last_who: String, line_no: int = 0) -> Dictionary:
	var who: String = ""
	var text: String = line

	# regex: 名字段(1-20字，不含引号) + 冒号 + 内容
	var colon_re := RegEx.new()
	colon_re.compile('^([^"\'：]{1,20})[：:](.*)$')
	var m := colon_re.search(line)
	if m:
		who = m.get_string(1).strip_edges()
		text = m.get_string(2).strip_edges()
		# 冒号后紧跟引号 → 旁白里的引语（如 他说："你好"），不是对话
		if text.begins_with('"') or text.begins_with('"') or text.begins_with("'"):
			who = ""
			text = line

	var node := _make_node("text", line_no)
	node.ZH = text; node.EN = ""; node.who = who

	if who.is_empty():
		if not last_who.is_empty(): node.ch = "__CLEAR__"
	else:
		if who != last_who: node.ch = who

	return {"node": node, "last_who": who}


# ═══════════════════════════════════════════════════════════════
# 选择解析
# ═══════════════════════════════════════════════════════════════

func _ensure_select_node(nodes: Array[PlotNode], cond_stack: Array[Dictionary]) -> PlotNode:
	# 查找当前上下文中最后一个节点是否为 select
	var target_array: Array[PlotNode] = nodes
	if not cond_stack.is_empty():
		@warning_ignore("unused_variable")
		var top: Dictionary = cond_stack[cond_stack.size() - 1]
		# 在 cond_stack 内部时，select 也是直接加到主 nodes 数组
		pass

	if target_array.size() > 0:
		var last: PlotNode = target_array[target_array.size() - 1]
		if last.type == "select": return last

	var sel := _make_node("select")
	sel.ZH = ""; sel.EN = ""; sel.options = []
	target_array.append(sel)
	return sel


func _parse_option(line: String) -> PlotOption:
	var opt := PlotOption.new()
	var content: String = line.substr(1).strip_edges()

	# 解析花括号 actions：- 文本 -> target { expr1; expr2 }
	var actions_block: String = ""
	var brace_start: int = content.rfind("{")
	if brace_start >= 0 and content.ends_with("}"):
		actions_block = content.substr(brace_start + 1, content.length() - brace_start - 2).strip_edges()
		content = content.substr(0, brace_start).strip_edges()
		# 按 ; 分割，过滤空串
		for act: String in actions_block.split(";"):
			var trimmed: String = act.strip_edges()
			if not trimmed.is_empty():
				opt.actions.append(trimmed)

	var opt_match := RegEx.create_from_string(OPT_TARGET_REGEX).search(content)
	var text: String
	if opt_match:
		text = opt_match.get_string(1).strip_edges()
		_apply_option_target(opt, opt_match.get_string(2).strip_edges())
	else:
		text = content

	opt.ZH = text; opt.EN = ""
	return opt


func _apply_option_target(option: PlotOption, target: String) -> void:
	var t := target.strip_edges().to_lower()
	if t == "_continue": return
	if t == "_rechoose": option.rechoose = true; return
	# scene:MAP / scene:CALENDAR — 跳转到非 VN 场景
	if t.begins_with("scene:"):
		option.target_plot_id = target.strip_edges()    # 保留原始大小写
		return
	option.target_plot_id = target
	option.target_node_index = 0


# ═══════════════════════════════════════════════════════════════
# 反应块（缩进格式）
# ═══════════════════════════════════════════════════════════════

func _parse_reactions(lines: Array[String], start_idx: int, cond_stack: Array[Dictionary]) -> Array:
	if start_idx >= lines.size(): return [[], start_idx]
	var reaction_lines: Array[String] = []
	var idx: int = start_idx
	while idx < lines.size():
		var rline: String = lines[idx]
		if rline.begins_with(" ") or rline.begins_with("\t"):
			reaction_lines.append(rline.strip_edges())
			idx += 1
		else:
			break
	return [_parse_reaction_lines(reaction_lines, cond_stack), idx]


func _parse_reaction_lines(rlines: Array[String], cond_stack: Array[Dictionary]) -> Array[PlotNode]:
	var nodes: Array[PlotNode] = []
	var last_who: String = ""
	for ri: int in range(rlines.size()):
		var line: String = rlines[ri]
		if line.is_empty(): continue
		var line_no: int = -(ri + 1)   # 负行号表示反应块内（仅用于调试）

		if line.begins_with("@"):
			var cmd_match := RegEx.create_from_string(CMD_REGEX).search(line)
			if cmd_match:
				var cmd: String = cmd_match.get_string(1).to_lower()
				if cmd in FLOW_COMMANDS:
					var raw_args: String = cmd_match.get_string(2).strip_edges()
					_parse_flow_directive(cmd, raw_args, nodes, cond_stack, line_no)
					continue
			var node: PlotNode = _parse_directive(line, line_no)
			if node: nodes.append(node)
			continue

		# 选项不能出现在反应块中
		if line.begins_with("-"):
			push_warning("ScriptParser: options (-) are not allowed inside reaction blocks — ", line)
			continue

		var result: Dictionary = _parse_dialogue(line, last_who, line_no)
		nodes.append(result["node"])
		last_who = result["last_who"]
	return nodes


# ═══════════════════════════════════════════════════════════════
# 节点辅助
# ═══════════════════════════════════════════════════════════════

func _make_node(type: String, line_no: int = 0) -> PlotNode:
	var node := PlotNode.new()
	node.type = type
	node.line_number = line_no
	node.ZH = ""; node.EN = ""
	return node


## 将节点添加到正确的目标数组（cond_stack 非空时添加到最后一条 if 的 then/else 体）。
## 返回节点在 nodes 数组中的索引。
func _append_node(nodes: Array[PlotNode], cond_stack: Array[Dictionary], node: PlotNode) -> int:
	if cond_stack.is_empty():
		nodes.append(node)
		return nodes.size() - 1

	# 在 @if 内部时，节点仍添加进主数组（平铺模型）
	# 它们逻辑上属于当前 if 的 then 或 else 体
	nodes.append(node)
	return nodes.size() - 1


## 直接追加到 nodes（不经过 cond_stack 检查），用于 @endif 内部。
func _append_node_raw(nodes: Array[PlotNode], node: PlotNode) -> int:
	nodes.append(node)
	return nodes.size() - 1


# ═══════════════════════════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════════════════════════

func _split_args(raw: String) -> Array[String]:
	if raw.is_empty(): return []
	var args: Array[String] = []
	var depth: int = 0; var start: int = 0
	for i: int in range(raw.length()):
		var ch: String = raw[i]
		if ch == "(" or ch == "（": depth += 1
		elif ch == ")" or ch == "）": depth -= 1
		elif ch == "," and depth == 0:
			args.append(raw.substr(start, i - start).strip_edges())
			start = i + 1
	args.append(raw.substr(start).strip_edges())
	return args
