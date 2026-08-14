## AchievementsData : RefCounted
## 成就系统的静态定义数据。
## ENTRIES 是唯一需手动维护的数据源 — 新增成就只需在此追加一行。
##   id     — 全局唯一标识（同时作为解锁 key）
##   name   — 成就名称（中文原文，UI 层用 tr() 翻译）
##   todo   — 达成条件描述（中文原文，UI 层用 tr() 翻译）
##   hide   — 是否隐藏成就（未达成时显示 ？？？，需点击揭示）
##   target — 计数型成就的目标次数（0 = 非计数型）
extends RefCounted

const ENTRIES: Array[Dictionary] = [
	{"id": "录取通知书", "name": "录取通知书", "todo": "成为火兰山中学学生",                       "hide": false, "target": 0},
	{"id": "好学生",     "name": "好学生",     "todo": "累计回答三次课堂抽问并全部答对",             "hide": false, "target": 3},
	{"id": "爱猫人士",   "name": "爱猫人士",   "todo": "累计与猫咪交互十次以上",                     "hide": false, "target": 10},
	{"id": "旗开得胜",   "name": "旗开得胜",   "todo": "完成OP1",                                    "hide": true,  "target": 0},
	{"id": "运筹帷幄",   "name": "运筹帷幄",   "todo": "完成OP5",                                    "hide": true,  "target": 0},
	{"id": "君子之交",   "name": "君子之交",   "todo": "与某位协助者协作程度达到满级",               "hide": false, "target": 0},
	{"id": "红颜知己",   "name": "红颜知己",   "todo": "和一名可攻略对象达成恋爱关系",               "hide": false, "target": 0},
	{"id": "薪火相传",   "name": "薪火相传",   "todo": "完成李大泉的谜题",                           "hide": true,  "target": 0},
	{"id": "不容遗漏",   "name": "不容遗漏",   "todo": "在任意一次行动中收集完全部线索",             "hide": false, "target": 0},
	{"id": "机智过人",   "name": "机智过人",   "todo": "在十分钟内解决任意一次行动",                 "hide": false, "target": 0},
	{"id": "遗憾",       "name": "遗憾",       "todo": "达成任意坏结局",                             "hide": false, "target": 0},
	{"id": "绝密·启用前", "name": "绝密·启用前", "todo": "解锁最终结局并通关",                       "hide": false, "target": 0},
]


## 按 id 查找单条成就定义。未找到返回空字典。
static func find_entry(p_id: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry.id == p_id:
			return entry
	return {}
