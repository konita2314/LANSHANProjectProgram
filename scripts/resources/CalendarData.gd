## CalendarData : RefCounted
## 游戏日历日程数据 — 2022-08-28 至 2022-11-15
## 除 date 外所有字段留空，待填入实际内容。
class_name CalendarData extends RefCounted

const MIN_DATE_STR: String = "2022-08-28"
const MAX_DATE_STR: String = "2022-11-15"

const SCHEDULE: Array[Dictionary] = [
	# ═══ 2022年8月 ═══
	{"date": "2022-08-28", "event": true, "things": "开学第一天","weather":""},
	{"date": "2022-08-29", "event": false, "things": "","weather":""},
	{"date": "2022-08-30", "event": false, "things": "","weather":""},
	{"date": "2022-08-31", "event": false, "things": "","weather":""},

	# ═══ 2022年9月 ═══
	{"date": "2022-09-01", "event": false, "things": "","weather":""},
	{"date": "2022-09-02", "event": false, "things": "","weather":""},
	{"date": "2022-09-03", "event": false, "things": "","weather":""},
	{"date": "2022-09-04", "event": false, "things": "","weather":""},
	{"date": "2022-09-05", "event": false, "things": "","weather":""},
	{"date": "2022-09-06", "event": false, "things": "","weather":""},
	{"date": "2022-09-07", "event": false, "things": "","weather":""},
	{"date": "2022-09-08", "event": false, "things": "","weather":""},
	{"date": "2022-09-09", "event": false, "things": "","weather":""},
	{"date": "2022-09-10", "event": false, "things": "","weather":""},
	{"date": "2022-09-11", "event": false, "things": "","weather":""},
	{"date": "2022-09-12", "event": false, "things": "","weather":""},
	{"date": "2022-09-13", "event": false, "things": "","weather":""},
	{"date": "2022-09-14", "event": false, "things": "","weather":""},
	{"date": "2022-09-15", "event": false, "things": "","weather":""},
	{"date": "2022-09-16", "event": false, "things": "","weather":""},
	{"date": "2022-09-17", "event": false, "things": "","weather":""},
	{"date": "2022-09-18", "event": false, "things": "","weather":""},
	{"date": "2022-09-19", "event": false, "things": "","weather":""},
	{"date": "2022-09-20", "event": false, "things": "","weather":""},
	{"date": "2022-09-21", "event": false, "things": "","weather":""},
	{"date": "2022-09-22", "event": false, "things": "","weather":""},
	{"date": "2022-09-23", "event": false, "things": "","weather":""},
	{"date": "2022-09-23", "event": false, "things": "","weather":""},
	{"date": "2022-09-24", "event": false, "things": "","weather":""},
	{"date": "2022-09-25", "event": false, "things": "","weather":""},
	{"date": "2022-09-26", "event": false, "things": "","weather":""},
	{"date": "2022-09-27", "event": false, "things": "","weather":""},
	{"date": "2022-09-28", "event": false, "things": "","weather":""},
	{"date": "2022-09-29", "event": false, "things": "","weather":""},
	{"date": "2022-09-30", "event": false, "things": "","weather":""},

	# ═══ 2022年10月 ═══
	{"date": "2022-10-01", "event": false, "things": "","weather":""},
	{"date": "2022-10-02", "event": false, "things": "","weather":""},
	{"date": "2022-10-03", "event": false, "things": "","weather":""},
	{"date": "2022-10-04", "event": false, "things": "","weather":""},
	{"date": "2022-10-05", "event": false, "things": "","weather":""},
	{"date": "2022-10-06", "event": false, "things": "","weather":""},
	{"date": "2022-10-07", "event": false, "things": "","weather":""},
	{"date": "2022-10-08", "event": false, "things": "","weather":""},
	{"date": "2022-10-09", "event": false, "things": "","weather":""},
	{"date": "2022-10-10", "event": false, "things": "","weather":""},
	{"date": "2022-10-11", "event": false, "things": "","weather":""},
	{"date": "2022-10-12", "event": false, "things": "","weather":""},
	{"date": "2022-10-13", "event": false, "things": "","weather":""},
	{"date": "2022-10-14", "event": false, "things": "","weather":""},
	{"date": "2022-10-15", "event": false, "things": "","weather":""},
	{"date": "2022-10-16", "event": false, "things": "","weather":""},
	{"date": "2022-10-17", "event": false, "things": "","weather":""},
	{"date": "2022-10-18", "event": false, "things": "","weather":""},
	{"date": "2022-10-19", "event": false, "things": "","weather":""},
	{"date": "2022-10-20", "event": false, "things": "","weather":""},
	{"date": "2022-10-21", "event": false, "things": "","weather":""},
	{"date": "2022-10-22", "event": false, "things": "","weather":""},
	{"date": "2022-10-23", "event": false, "things": "","weather":""},
	{"date": "2022-10-24", "event": false, "things": "","weather":""},
	{"date": "2022-10-25", "event": false, "things": "","weather":""},
	{"date": "2022-10-26", "event": false, "things": "","weather":""},
	{"date": "2022-10-27", "event": false, "things": "","weather":""},
	{"date": "2022-10-28", "event": false, "things": "","weather":""},
	{"date": "2022-10-29", "event": false, "things": "","weather":""},
	{"date": "2022-10-30", "event": false, "things": "","weather":""},
	{"date": "2022-10-31", "event": false, "things": "","weather":""},

	# ═══ 2022年11月 ═══
	{"date": "2022-11-01", "event": false, "things": "","weather":""},
	{"date": "2022-11-02", "event": false, "things": "","weather":""},
	{"date": "2022-11-03", "event": false, "things": "","weather":""},
	{"date": "2022-11-04", "event": false, "things": "","weather":""},
	{"date": "2022-11-05", "event": false, "things": "","weather":""},
	{"date": "2022-11-05", "event": false, "things": "","weather":""},
	{"date": "2022-11-06", "event": false, "things": "","weather":""},
	{"date": "2022-11-07", "event": false, "things": "","weather":""},
	{"date": "2022-11-08", "event": false, "things": "","weather":""},
	{"date": "2022-11-09", "event": false, "things": "","weather":""},
	{"date": "2022-11-10", "event": false, "things": "","weather":""},
	{"date": "2022-11-11", "event": false, "things": "","weather":""},
	{"date": "2022-11-12", "event": false, "things": "","weather":""},
	{"date": "2022-11-13", "event": false, "things": "","weather":""},
	{"date": "2022-11-14", "event": false, "things": "","weather":""},
	{"date": "2022-11-15", "event": false, "things": "","weather":""},
]


## 查找某个日期的日程条目，找不到返回空 Dictionary。
static func get_entry(date_str: String) -> Dictionary:
	for entry: Dictionary in SCHEDULE:
		if entry.date == date_str:
			return entry
	return {}


## 获取指定月份的所有条目。
static func get_month_entries(year: int, month: int) -> Array[Dictionary]:
	var prefix: String = str(year) + "-" + ("0" + str(month) if month < 10 else str(month))
	var result: Array[Dictionary] = []
	for entry: Dictionary in SCHEDULE:
		if (entry.date as String).begins_with(prefix):
			result.append(entry)
	return result
