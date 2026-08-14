## MapData : RefCounted
## 校园地图地点静态数据 — Map.gd 与 GameManager（地点系统校验）共享。
## LOCATIONS 原为 Map.gd 内常量，2026-08 上移至此以支撑 @locate / API 校验。
class_name MapData extends RefCounted

const LOCATIONS: Array[Dictionary] = [
	{"name": "北门",         "description": "大家经常会走的大门。",                     "x": 609,  "y": 396},
	{"name": "科技楼",       "description": "学校的行政楼。",                          "x": 679,  "y": 363},
	{"name": "逸天楼",       "description": "高一的教学楼。我的教室在这里。",            "x": 574,  "y": 559},
	{"name": "哲贵楼",       "description": "高一的教学楼。",                          "x": 570,  "y": 464},
	{"name": "老校区楼",     "description": "似乎已经作废的地方。",                     "x": 866,  "y": 256},
	{"name": "博雅楼",       "description": "高二的教学楼。",                          "x": 485,  "y": 600},
	{"name": "图书馆",       "description": "学校图书馆。应该能在这看到什么。",          "x": 917,  "y": 691},
	{"name": "食堂",         "description": "学校食堂。挺不便宜的。",                   "x": 860,  "y": 653},
	{"name": "桃园",         "description": "高一部分的寝室。",                        "x": 866,  "y": 359},
	{"name": "李园",         "description": "高二的寝室楼。",                          "x": 714,  "y": 597},
	{"name": "高三校区",     "description": "学校的高三学区。",                        "x": 1053, "y": 188},
	{"name": "操场",         "description": "学校的操场。",                            "x": 824,  "y": 463},
	{"name": "篮球场",       "description": "学校的篮球场。",                          "x": 794,  "y": 559},
	{"name": "乒乓球场",     "description": "乒乓球场，就在操场旁边。",                  "x": 920,  "y": 559},
	{"name": "兰园",         "description": "很大的女生寝室。",                        "x": 725,  "y": 672},
	{"name": "小卖部",       "description": "应该能在这买点东西。",                     "x": 817,  "y": 638},
	{"name": "后山",         "description": "后山公园，现在还正在建设。",                "x": 1174, "y": 678},
	{"name": "体育馆",       "description": "似乎没什么用的体育馆。",                   "x": 1085, "y": 713},
	{"name": "南门",         "description": "临近二环路的大门，交通比较方便。",          "x": 964,  "y": 778},
	{"name": "高三校区门",   "description": "高三校区的专用大门。",                     "x": 872,  "y": 167},
	{"name": "桂园",        "description": "高一男生寝室。我住在这。",                 "x": 1161,  "y": 806},
]


## 名称 → 索引；找不到返回 -1。
## 21 项线性搜索开销可忽略；若未来地点膨胀，可改为静态字典缓存（初始化时构建一次）。
static func get_index(loc_name: String) -> int:
	if loc_name.is_empty():
		return -1
	for i: int in LOCATIONS.size():
		if LOCATIONS[i].name == loc_name:
			return i
	return -1


## 该名称是否存在于地图数据。
static func has_location(loc_name: String) -> bool:
	return get_index(loc_name) >= 0
