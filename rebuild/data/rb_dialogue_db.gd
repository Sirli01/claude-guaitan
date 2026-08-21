class_name RbDialogueDb
## rebuild 对话内容数据源。
##
## 纯数据，不含逻辑。业务代码只通过 dialogue_id 取内容，不直接读 LINES。

const STREET_INTRO: String = "street_intro"
const STREET_DOOR_LOCKED: String = "street_door_locked"
const ROOM_INTRO: String = "room_intro"
const ROOM_PHONE_FIRST: String = "room_phone_first"
const ROOM_PHONE_REPEAT: String = "room_phone_repeat"

const LINES: Dictionary = {
	STREET_INTRO: [
		{"speaker": "林夏", "text": "……雨停了。路灯还亮着，可街上一个人都没有。"},
		{"speaker": "林夏", "text": "姐姐发来的最后一条消息，就停在这栋楼的门牌号上。"},
		{"speaker": "旁白", "text": "（WASD 移动，走到门前按空格进入。）"},
	],
	STREET_DOOR_LOCKED: [
		{"speaker": "林夏", "text": "门把手纹丝不动。……有人从里面锁上了。"},
	],
	ROOM_INTRO: [
		{"speaker": "林夏", "text": "屋里没开灯。空气里有一股放久了的雨水味。"},
		{"speaker": "林夏", "text": "床铺是整理过的，桌子却翻得乱七八糟。"},
	],
	ROOM_PHONE_FIRST: [
		{"speaker": "林夏", "text": "地上躺着一部手机。屏幕还亮着——是姐姐的。"},
		{"speaker": "手机", "text": "「别信任何看起来正常的人。」"},
		{"speaker": "手机", "text": "「如果你看到了这条消息，说明我已经不在三楼了。」"},
		{"speaker": "林夏", "text": "……三楼。"},
	],
	ROOM_PHONE_REPEAT: [
		{"speaker": "林夏", "text": "屏幕已经黑了。我不想再看第二遍。"},
	],
}


static func has_dialogue(dialogue_id: String) -> bool:
	return LINES.has(dialogue_id)


## 取得一段对话的全部行。未知 id 返回空数组并发出警告，不抛异常。
static func get_lines(dialogue_id: String) -> Array[RbDialogueLine]:
	var result: Array[RbDialogueLine] = []
	if not LINES.has(dialogue_id):
		push_warning("[RbDialogueDb] 未知对话 id: %s" % dialogue_id)
		return result

	var raw_lines: Array = LINES[dialogue_id]
	for entry: Dictionary in raw_lines:
		result.append(RbDialogueLine.new(
			str(entry.get("speaker", "")),
			str(entry.get("text", ""))
		))
	return result
