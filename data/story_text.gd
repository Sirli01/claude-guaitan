class_name StoryText
## ========================================
## 《失序者的生存守则》全部剧情文本
## ========================================
## 改台词只需要改这个文件！
##
## 格式:  ["角色ID", "台词文本"]         ← 无表情（默认头像）
##         ["角色ID", "台词文本", "表情ID"]  ← 有表情（用对应头像）
##   表情ID 与 PORTRAIT_MAP 中的 "角色名/表情ID" 对应，
##   例如 PORTRAIT_MAP["夏桐/happy"] = "res://assets/sprites/portraits/夏桐_happy.png"
##   角色ID 对照表（在 game_manager.gd 的 NAMES 里改名字）:
##     ""               → 旁白/系统叙述
##     "sister"         → 夏桐（玩家/姐姐）
##     "cool_npc"       → 林佳语（被夺舍的妹妹）
##     "cheerful_npc"   → 鹿可
##     "male_npc"       → 周锐
##     "female_npc"     → 沈薇
##     "timid_male"     → 余凡
##
## 用法:
##   DialogueManager.start_dialogue(StoryText.lines("floor_1", "entry"))
##

## 当前语言（由 LocaleManager 统一写入）
static var _locale: String = "zh"

## ====== 获取对话（自动把角色ID转成显示名）======
static func lines(chapter: String, event: String) -> Array:
	var key := chapter + "." + event
	var raw: Array
	match _locale:
		"en": raw = StoryTextEN.LINES.get(key, [])
		"ja": raw = StoryTextJA.LINES.get(key, [])
		_:    raw = LINES.get(key, [])
	raw = _override_lines_for_demo(key, raw)
	if raw.is_empty():
		push_warning("StoryText: 找不到对话 '%s'" % key)
		return []
	var result := []
	for line in raw:
		var emotion = line[2] if line.size() > 2 else ""
		result.append(GameManager.say(line[0], line[1], emotion))
	return result

static func _override_lines_for_demo(key: String, raw: Array) -> Array:
	match _locale:
		"en":
			match key:
				"floor_1.elevator":
					return [
						["", "Everyone crowded into the elevator."],
						["male_npc", "Hold on.", "serious"],
						["", "Zhou Rui stared at Shen Wei for a long moment."],
						["male_npc", "Wei... aren't you left-handed? Just now you were using your right.", "serious"],
						["female_npc", "...What? I've always used my right hand.", "surprised"],
						["male_npc", "No — I've lived with you for two years. You eat, write, text — all left-handed—", "angry"],
						["female_npc", "You must be misremembering. Are we going or not?", "serious"],
						["", "Zhou Rui's expression froze."],
						["cool_npc", "...", "serious"],
						["cool_npc", "At 11 PM, she saw her own eyes in the mirror.", "serious"],
						["cheerful_npc", "S-so what does that mean?", "scared"],
						["cool_npc", "Eye contact after 11 brings something bad with it. Don't look into her eyes again.", "serious"],
						["cool_npc", "Wait until 7 AM before deciding who she is. Until then, we leave this floor.", "serious"],
						["", "No one said a word."],
						["sister", "...We don't have time for this now. We leave first.", "serious"],
						["timid_male", "R-right, right... let's just go...", "nervous"],
						["", "There was only one button in the elevator: up."],
						["timid_male", "Only up?! We can't go back down?!", "scared"],
						["cool_npc", "We don't have a choice.", "serious"],
						["", "The elevator began to rise..."],
					]
				"floor_2.earplug_branch":
					return [
						["sister", "(The earplugs — I picked them up near Yu Fan!)", "surprised"],
						["sister", "Lu Ke! Catch!", "serious"],
						["", "Xia Tong threw the earplugs to Lu Ke."],
						["sister", "Put them in! Quickly!", "serious"],
						["", "Lu Ke's trembling hands managed to press them into her ears."],
						["", "The clicking continues... but Lu Ke can no longer hear it."],
						["cheerful_npc", "...I can't hear it? No... it's not gone, I just can't hear it anymore...", "scared"],
						["cheerful_npc", "Is it still above me...?", "scared"],
						["", "As if losing its lock — the footsteps above falter, slow, and fade to silence."],
						["cheerful_npc", "...Gone? It's gone...?", "surprised"],
						["sister", "Get over here! Back to the middle of the group!", "serious"],
					]
				"floor_3.card_found":
					return [
						["sister", "(Got the card... but that thing is still coming.)", "nervous"],
						["sister", "(We can't leave — it's blocking the path to the elevator.)", "nervous"],
						["sister", "(Wait... what time is it? Almost 7 AM...)", "serious"],
						["sister", "(Floor One's rule — 'No eye contact.' Lin Jiayu said eye contact causes soul transference. And at 7, the souls return.)", "serious"],
						["sister", "(...What if I make eye contact with that thing?)", "serious"],
						["sister", "(Swap souls — I enter its body, and use it to run—)", "serious"],
						["sister", "(The creature under the floor will swallow it whole.)", "serious"],
						["sister", "(And then I just have to hold on until 7 AM. The soul returns on its own.)", "serious"],
						["sister", "(But... what if I die before 7? What if I can't come back?)", "scared"],
						["sister", "(We're already almost at 7. A few minutes are all I need.)", "serious"],
						["sister", "(This is the only way. I need to tell the others.)", "serious"],
					]
		"ja":
			match key:
				"floor_1.elevator":
					return [
						["", "全員でエレベーターに乗り込んだ。"],
						["male_npc", "ちょっと待て。", "serious"],
						["", "周锐は沈薇をしばらくじっと見つめた。"],
						["male_npc", "薇薇……お前って左利きじゃなかったか？今、右手で操作してた。", "serious"],
						["female_npc", "……何が？ずっと右利きだけど。", "surprised"],
						["male_npc", "違う、一緒に住んで二年になる、飯も字も全部左手——", "angry"],
						["female_npc", "記憶違いでしょ。行くの、行かないの？", "serious"],
						["", "周锐の表情が固まった。"],
						["cool_npc", "……", "serious"],
						["cool_npc", "さっき23時に、彼女は鏡の中で自分の目を見た。", "serious"],
						["cheerful_npc", "そ、それで……？", "scared"],
						["cool_npc", "23時以降の視線は危ない。もう彼女の目を見ないで。", "serious"],
						["cool_npc", "朝7時になるまで、彼女が誰かは決めないで。それまでにまずこの階を出る。", "serious"],
						["", "誰も口を開かなかった。"],
						["sister", "……今はそれを確かめてる場合じゃない。先にここを離れよう。", "serious"],
						["timid_male", "そ、そうだよ……早く行こう……", "nervous"],
						["", "エレベーターのボタンは一つだけだった——上。"],
						["timid_male", "上だけ？！ 下には行けないのか？！", "scared"],
						["cool_npc", "選べないわ。", "serious"],
						["", "エレベーターはゆっくりと上昇し始めた……"],
					]
				"floor_2.earplug_branch":
					return [
						["sister", "（そうだ——さっき余凡のそばで拾った耳栓！）", "surprised"],
						["sister", "鹿可！受け取って！", "serious"],
						["", "夏桐は耳栓を鹿可に向けて投げた。"],
						["sister", "つけて！早く！", "serious"],
						["", "鹿可の震える手がなんとか耳栓を耳に押し込んだ。"],
						["", "音はまだ続いている……でも鹿可には何も聞こえない。"],
						["cheerful_npc", "……聞こえない？ ちがう……消えたんじゃない、私に聞こえなくなっただけ……", "scared"],
						["cheerful_npc", "まだ……まだ真上にいるの……？", "scared"],
						["", "ロックを失ったかのように——頭上の音が迷い、弱まり……やがて消えた。"],
						["cheerful_npc", "……消えた？消えたの……？", "surprised"],
						["sister", "こっちへ！ 列の真ん中に戻って！", "serious"],
					]
				"floor_3.card_found":
					return [
						["sister", "（カードを手に入れた……でも、あの怪物はまだ近づいてる）", "nervous"],
						["sister", "（逃げられない——エレベーターへの道を塞いでる）", "nervous"],
						["sister", "（待って……今何時？もうすぐ7時……）", "serious"],
						["sister", "（一層目のルール——「目を合わせるな」。林佳語が言ってた、視線が交わると魂が入れ替わる。7時になれば自動的に元に戻るって）", "serious"],
						["sister", "（……あの怪物と目を合わせたら？）", "serious"],
						["sister", "（魂を入れ替えて……あの体に入って、走らせれば——）", "serious"],
						["sister", "（床下の怪物が飲み込む！）", "serious"],
						["sister", "（そして7時まで耐えれば……魂は自動的に戻ってくる！）", "serious"],
						["sister", "（でも……7時になる前に死んだら？ 戻れなかったら？）", "scared"],
						["sister", "（もうすぐ7時だ、数分だけ耐えればいい！）", "serious"],
						["sister", "（これしかない。みんなに伝えないと。）", "serious"],
					]
		_:
			match key:
				"floor_1.elevator":
					return [
						["", "众人进入了电梯 。"],
						["male_npc", "等一下。", "serious"],
						["", "周锐盯着沈薇看了好一会儿。"],
						["male_npc", "薇薇……你不是左撇子吗？刚才你用的是右手。", "serious"],
						["female_npc", "……什么？我一直都用右手啊。", "surprised"],
						["male_npc", "不对，我跟你住了两年了，你吃饭写字全是用左手——", "angry"],
						["female_npc", "你记错了吧。走不走？", "serious"],
						["", "周锐的表情僵住了。"],
						["cool_npc", "……", "serious"],
						["cool_npc", "刚才23点，她在镜子里看见了自己的眼睛。", "serious"],
						["cheerful_npc", "所、所以呢？", "scared"],
						["cool_npc", "23点后的对视会出事。别再盯着她的眼睛看。", "serious"],
						["cool_npc", "等到早上七点再确认她是谁。在那之前，先离开这一层。", "serious"],
						["", "所有人沉默了。"],
						["sister", "……现在说这些也来不及了。先离开这里。", "serious"],
						["timid_male", "对对对，赶紧走赶紧走……", "nervous"],
						["", "电梯只有一个按钮——向上。"],
						["timid_male", "只能往上？不能下去吗？！", "scared"],
						["cool_npc", "没有选择。", "serious"],
						["", "电梯缓缓上升……"],
					]
				"floor_2.earplug_branch":
					return [
						["sister", "（对了——之前在余凡身边捡到的耳塞！）", "surprised"],
						["sister", "鹿可！接住！", "serious"],
						["", "夏桐把耳塞扔向了鹿可。"],
						["sister", "戴上！快戴上！", "serious"],
						["", "鹿可颤抖着把耳塞塞进了耳朵。"],
						["", "高跟鞋声依然在响……但鹿可什么都听不到了。"],
						["cheerful_npc", "……听不见了？不对……是我听不见它了……", "scared"],
						["cheerful_npc", "它是不是还在我头顶……？", "scared"],
						["", "仿佛失去了某种锁定——头顶的声音开始变得迟疑，越来越弱……最终消失了。"],
						["cheerful_npc", "……没了？消失了……？", "surprised"],
						["sister", "快过来！站到队伍中间来！", "serious"],
					]
				"floor_3.card_found":
					return [
						["sister", "（拿到电梯卡了……但那个东西还在向这边走。）", "nervous"],
						["sister", "（我们走不了——它堵在电梯的方向。）", "nervous"],
						["sister", "（等一下……现在几点了？快七点了……）", "serious"],
						["sister", "（第一层的规则——「禁止对视」。林佳语说过对视会导致灵魂互换，七点就能换回来。）", "serious"],
						["sister", "（……如果我和那个怪物对视呢？）", "serious"],
						["sister", "（互换灵魂……我进入它的身体，操控它去跑步——）", "serious"],
						["sister", "（地板下面的怪物会把它吞掉！）", "serious"],
						["sister", "（然后撑到七点……灵魂就会自动回来！）", "serious"],
						["sister", "（可是……要是七点前死了呢？要是回不来呢？）", "scared"],
						["sister", "（现在已经快七点了，只要撑几分钟就行！）", "serious"],
						["sister", "（这是唯一的办法了。叫她们过来。）", "serious"],
					]
	return raw

## ====== 获取结局纯文本 ======
static func get_ending_text(section: String) -> String:
	match _locale:
		"en": return StoryTextEN.ENDING_TEXT.get(section, "")
		"ja": return StoryTextJA.ENDING_TEXT.get(section, "")
		_:    return ENDING_TEXT.get(section, "")

# ╔══════════════════════════════════════════╗
# ║           序 章 · 夏桐的房间             ║
# ╚══════════════════════════════════════════╝

# ╔══════════════════════════════════════════╗
# ║           序 章 · 街 道                  ║
# ╚══════════════════════════════════════════╝
# （街道场景没有对话，只有提示文字）

# ╔══════════════════════════════════════════╗
# ║           第 一 层                        ║
# ╚══════════════════════════════════════════╝

# ╔══════════════════════════════════════════╗
# ║           第 二 层                        ║
# ╚══════════════════════════════════════════╝

# ╔══════════════════════════════════════════╗
# ║           第 三 层                        ║
# ╚══════════════════════════════════════════╝

# ╔══════════════════════════════════════════╗
# ║           结 局                           ║
# ╚══════════════════════════════════════════╝

const LINES := {
	# ============ 序章：夏桐的房间 ============
	# （手机聊天已改用 phone_ui.gd 的 CHAT_DATA，此条仅作备份）
	"prologue.phone_chat": [
		["sister", "（翻开手机，查看和妹妹的聊天记录……）", "serious"],
	],
	"prologue.intro": [
		["sister", "妹妹已经两天没有回消息了。"],
		["sister", "她说搬去了一个叫「归栖公寓」的地方……"],
		["sister", "从那之后就再也联系不上了。"],
		["sister", "我必须亲自去看看。"],
	],

	# ============ 第一层 ============
	"floor_1.entry": [
		["sister", "（这里就是归栖公寓……？看起来比我想象的还要破旧。）", "nervous"],
		["cheerful_npc", "啊！那边有光——还有别人在啊？", "surprised"],
		["sister", "你好……你们也是住在这里的吗？我叫夏桐，我妹妹住在这栋公寓，但她两天没回我消息了。", "serious"],
		["cheerful_npc", "两天？那也太吓人了吧……我叫鹿可，住103。今天下课回来不知道怎么就昏过去了，醒来发现自己在走廊里。", "surprised"],
		["male_npc", "周锐。这是我女朋友沈薇，我们合租304。", "serious"],
		["female_npc", "……我俩躺床上准备睡了，然后就什么都不记得了。醒过来就在这走廊里，黑成这样。", "serious"],
		["male_npc", "我也是。完全不知道发生了什么。", "nervous"],
		["sister", "全都昏过去了……？", "surprised"],
		["timid_male", "我……我叫余凡，住601的……我也是突然晕过去的，醒来电梯就不能用了……", "nervous"],
		["cheerful_npc", "你妹妹叫什么？我们可能见过。", "surprised"],
		["sister", "夏澈。你们有人认识她吗？", "nervous"],
		["cool_npc", "……没听说过。", "serious"],
		["cheerful_npc", "我也没印象……对不起。"],
		["male_npc", "说不定她比我们先醒，已经出去了。", "serious"],
		["cheerful_npc", "对啊，说不定已经出去了呢！", "happy"],
		["sister", "……但愿吧。", "sad"],
		["cool_npc", "……", "serious"],
		["cheerful_npc", "那你呢？你也住这里？", "surprised"],
		["cool_npc", "嗯。", "serious"],
		["male_npc", "这里明显出了什么问题。大门从外面锁死了，我们刚才试过了，出不去。", "serious"],
		["timid_male", "电……电梯也不能用了，需要刷什么电梯卡……", "nervous"],
		["male_npc", "大门出不去，楼梯也没找到，看来只能想办法找到电梯卡了。", "serious"],
		["sister", "……先别在这儿站着了。分头找找吧，钥匙、电梯卡、任何有用的东西都行。", "serious"],
		["male_npc", "走。反正赶紧找出路。", "serious"],
	],
	"floor_1.dark_intro": [
		["sister", "什么都看不见……"],
		["sister", "先用手机照一下路。"],
	],
	"floor_1.rule_question": [
		["sister", "等等……你们看看口袋。是不是也有一张纸条？", "surprised"],
		["cheerful_npc", "啊——真的有！我醒来的时候口袋里就有了……", "surprised"],
		["male_npc", "我也是。上面写着什么规则，之前没当回事。", "serious"],
		["female_npc", "我以为是谁的恶作剧。", "serious"],
		["timid_male", "我……我也有……上面的字看起来好可怕……", "scared"],
		["cool_npc", "这栋公寓……我住了很久了，但从来没见过这种东西。", "serious"],
		["cheerful_npc", "说起来好奇怪，明明是自己家，但走出房间之后总觉得哪里变了……", "surprised"],
		["male_npc", "楼道的结构好像也不太一样了。之前没有这么多弯弯绕绕的。", "nervous"],
		["cool_npc", "不管上面写的是什么意思……我建议不要打破规则。", "serious"],
		["sister", "……嗯。", "serious"],
	],
	"floor_1.mirror": [
		["cool_npc", "……已经23点了。", "serious"],
		["cool_npc", "规则上写的是「禁止对视」——从现在开始，所有人都别看别人的眼睛。", "serious"],
		["cheerful_npc", "这么夸张吗……", "nervous"],
		["cool_npc", "宁可信其有。小心一点。", "serious"],
		["", "时钟指向了 23:00……走廊的灯突然全灭了，只剩应急灯发出暗红色的光。"],
		["cheerful_npc", "怎、怎么回事？！", "surprised"],
		["female_npc", "别大惊小怪的，可能就是跳闸了。", "serious"],
		["", "走廊尽头有一面落地穿衣镜。"],
		["female_npc", "啊，这里有面镜子……规则只说了不能对视，又没说不能照镜子。", "surprised"],
		["male_npc", "别过去！", "scared"],
		["female_npc", "你紧张什么，就是照个镜子。", "serious"],
		["", "沈薇走到镜子前，习惯性地整理了一下头发。"],
		["cool_npc", "……不要盯着镜子看。", "serious"],
		["female_npc", "嗯？", "surprised"],
		["", "但沈薇已经看见了——镜子里的自己的眼睛。"],
		["", "她和镜中的倒影对视了。"],
		["", "……"],
		["", "一阵眩晕过后，似乎什么都没发生。"],
		["female_npc", "……没事啊。你们太紧张了。", "serious"],
		["cool_npc", "……走吧。", "serious"],
	],
	"floor_1.notice": [
		# （左撇子发现已移至电梯场景，此处留空作为过渡）
	],
	"floor_1.elevator": [
		["", "众人来到了电梯口。"],
		["male_npc", "等一下。", "serious"],
		["", "周锐盯着沈薇看了好一会儿。"],
		["male_npc", "薇薇……你不是左撇子吗？刚才你用的是右手。", "serious"],
		["female_npc", "……什么？我一直都用右手啊。", "surprised"],
		["male_npc", "不对，我跟你住了两年了，你吃饭写字全是用左手——", "angry"],
		["female_npc", "你记错了吧。走不走？", "serious"],
		["", "周锐的表情僵住了。"],
		["cool_npc", "……", "serious"],
		["cool_npc", "刚才23点，她对着镜子看了自己的眼睛。", "serious"],
		["cheerful_npc", "所、所以呢？", "scared"],
		["cool_npc", "对视会导致灵魂互换。", "serious"],
		["cool_npc", "不过到了早上七点，灵魂会自动换回来。所以……暂时不用太担心。", "serious"],
		["", "所有人沉默了。"],
		["sister", "……现在说这些也来不及了。先离开这里。", "serious"],
		["timid_male", "对对对，赶紧走赶紧走……", "nervous"],
		["", "电梯只有一个按钮——向上。"],
		["timid_male", "只能往上？不能下去吗？？", "scared"],
		["cool_npc", "没有选择。", "serious"],
		["", "电梯缓缓上升……"],
	],
	"floor_1.enter_elevator_scene": [
		["", "夏桐将电梯卡插入卡槽。"],
		["", "咔嗒一声，指示灯亮了——电梯缓缓打开。"],
	],
	"floor_1.talk_explore_cool": [
		["cool_npc", "这层的走廊和我记忆里的不一样。别走太散，找到电梯卡就立刻回来。", "serious"],
	],
	"floor_1.talk_explore_cheerful": [
		["cheerful_npc", "要是看到亮一点的地方记得叫我……我一个人搜总觉得心里发毛。", "nervous"],
	],
	"floor_1.talk_explore_male": [
		["male_npc", "先找电梯卡。门和窗我都试过了，根本打不开。", "serious"],
	],
	"floor_1.talk_explore_female": [
		["female_npc", "别搞得像灵异探险，找到卡就走人。我可不想在这种地方待一整晚。", "serious"],
	],
	"floor_1.talk_explore_timid": [
		["timid_male", "我会看看墙角和柜子……你们要是找到路，记得第一时间叫我。", "nervous"],
	],
	"floor_1.talk_post_mirror_cool": [
		["cool_npc", "别和任何人对视，也别再照镜子。先去电梯，剩下的事离开这一层再说。", "serious"],
	],
	"floor_1.talk_post_mirror_cheerful": [
		["cheerful_npc", "我现在连抬头都不敢了……夏桐，你走前面好不好？", "nervous"],
	],
	"floor_1.talk_post_mirror_male": [
		["male_npc", "薇薇，你别离我太远……等上了电梯，我们再把话说清楚。", "nervous"],
	],
	"floor_1.talk_post_mirror_female": [
		["female_npc", "你们一个个都盯着我做什么？不是要走吗，那就去电梯。", "serious"],
	],
	"floor_1.talk_post_mirror_timid": [
		["timid_male", "别停在这层了……我总觉得再待下去，还会出事。", "scared"],
	],

	# ============ 第二层 ============
	"floor_2.entry": [
		["", "电梯门打开，一股潮湿腐朽的气息扑面而来。"],
		["cheerful_npc", "好臭……这里是不是漏水了？", "surprised"],
		["timid_male", "我、我不想往前走了……到处都是黑的，什么都看不见。", "scared"],
		["timid_male", "我就在电梯口等你们，你们找到出路了叫我一声。", "nervous"],
		["male_npc", "随你，但你最好祈祷你一个人待着没事。", "angry"],
		["female_npc", "我去前面看看有没有别的通道。", "serious"],
		["male_npc", "你别乱走！你刚才——", "angry"],
		["female_npc", "刚才怎么了？你信那个人说的鬼话？灵魂互换？你认真的吗？", "serious"],
		["male_npc", "我不是那个意思，我是说——", "nervous"],
		["female_npc", "你是觉得我不是我了？真可笑。", "serious"],	],
	"floor_2.entry_after": [		["", "沈薇甩开周锐的手，头也不回地走向了走廊另一端。"],
		["male_npc", "……", "serious"],
		["sister", "……我们先走吧。小心点。", "nervous"],
	],
	"floor_2.timid_death": [
		["", "咔……咔……咔……"],
		["timid_male", "（高跟鞋声……？怎么会在天花板上？）", "nervous"],
		["timid_male", "（等等……为什么我走一步，它也跟一步？）", "scared"],
		["", "咔、咔、咔——"],
		["timid_male", "（它是在跟着我……只有我能听到？！）", "scared"],
		["timid_male", "（不……别过来……它离我越来越近了！！）", "scared"],
		["timid_male", "（有谁在吗……谁都好……救我……）", "scared"],
		["", "就在余凡的正上方——声音骤然停止。"],
	],
	"floor_2.rule_discover": [
		["", "口袋里的纸条突然变得灼热——上面多了一行血红色的新字。"],
		["sister", "（「禁止离群」……？！）", "surprised"],
		["sister", "（离群就会……！！）", "scared"],
		["cool_npc", "……果然。落单就是死路一条。", "serious"],
		["cheerful_npc", "等等！余凡呢？！他不是一个人在电梯口吗？！", "surprised"],
		["male_npc", "还有——沈薇也一个人走了！", "scared"],
		["sister", "（糟了……他们两个都是一个人——都离群了！）", "scared"],
		["female_npc", "周锐！！救我——！！", "scared"],
		["male_npc", "沈薇？！", "scared"],
		["cool_npc", "她还活着！在上面——快！", "serious"],
	],
	"floor_2.female_death_hear": [
		["", "咔……咔……"],
		["", "高跟鞋声再次响起——这次从走廊深处传来。"],
		["female_npc", "周锐！！我头顶有脚步声！！", "scared"],
		["female_npc", "它在跟着我——我跑一步，它就跟一步！！", "scared"],
		["female_npc", "不对……它已经到我头顶上了……！！", "scared"],
		["male_npc", "沈薇！！站着别动！我们过去找你！", "scared"],
		["sister", "先别回头！朝我们的声音过来！", "scared"],
	],
	"floor_2.female_death_run": [
		["", "沈薇拼命向队伍的方向跑去——"],
		["female_npc", "救——", "scared"],
		["", "她的下一声求救还没来得及喊出来，头顶的声音停了。"],
		["", "一只巨大的高跟鞋从天花板上直直坠落。"],
	],
	"floor_2.female_death_aftermath": [
		["male_npc", "不……沈薇！！沈薇！！！", "angry"],
		["male_npc", "不可能……她明明就快到了……就差那么一点……", "angry"],
		["cool_npc", "离群就会死。这就是第二层的规则。", "serious"],
		["cool_npc", "所有人贴紧。别再让任何人掉队。", "serious"],
		["male_npc", "……那第一层那件事，也是真的？", "angry"],
		["cool_npc", "是真的。我说过了，是你们不信。", "serious"],
	],
	"floor_2.cheerful_danger": [
		["", "众人紧挨着彼此，小心翼翼地向走廊深处移动。"],
		["", "但刚才所有人都冲向沈薇的时候——"],
		["", "鹿可的反应最慢，始终比其他人慢了半步。"],
		["", "不知不觉间，她已经落在了队伍的最后面。"],
		["", "咔……"],
		["cheerful_npc", "（不对……他们怎么越走越快了？）", "surprised"],
		["cheerful_npc", "（那个声音不是在追大家……是在追我？）", "scared"],
		["cheerful_npc", "（我明明只慢了半步……为什么只剩我一个人了？）", "scared"],
		["cheerful_npc", "（回头啊……谁回头看我一眼……）", "crying"],
		["cheerful_npc", "不要丢下我！！", "crying"],
	],
	"floor_2.earplug_branch": [
		["sister", "（对了——之前在余凡身边捡到的耳塞！）", "surprised"],
		["sister", "鹿可！接住！", "serious"],
		["", "夏桐把耳塞扔向了鹿可。"],
		["sister", "戴上！快戴上！", "serious"],
		["", "鹿可颤抖着把耳塞塞进了耳朵。"],
		["", "高跟鞋声依然在响……但鹿可什么都听不到了。"],
		["", "仿佛失去了某种锁定——头顶的声音开始变得迟疑，越来越弱……最终消失了。"],
		["cheerful_npc", "……没了？消失了……？", "surprised"],
		["sister", "快过来！站到队伍中间来！", "serious"],
	],
	"floor_2.wooden_man_branch": [
		["cool_npc", "不要动。", "serious"],
		["cheerful_npc", "什么？？", "surprised"],
		["cool_npc", "它跟的是你的脚步声。你停下来，它也会停。", "serious"],
		["sister", "像……123木头人？", "surprised"],
		["cool_npc", "差不多。", "serious"],
		["", "鹿可咬着嘴唇，拼了命地控制住双腿，一动不动。"],
		["", "头顶的「咔」也随之停住了。"],
		["", "一秒……两秒……三秒……五秒……"],
		["", "声音彻底消失了。"],
		["sister", "现在！！", "serious"],
		["", "众人一步冲上去，一把将她拉回了队伍中央。"],
	],
	"floor_2.rescue_complete": [
		["cheerful_npc", "呜呜……太可怕了……谢谢你们……", "crying"],
		["male_npc", "两个人……已经死了两个人了……", "scared"],
		["cool_npc", "活着的人紧靠在一起。一步都不要落下。", "serious"],
		["cool_npc", "先找到电梯卡。", "serious"],
	],
	"floor_2.enter_elevator": [
		["", "幸存者们踏入了电梯。"],
		["", "按钮依然只有一个——向上。"],
		["", "没有人说话。"],
		["", "电梯缓缓上升……"],
	],
	"floor_2.phone_dead": [
		["sister", "手机……没电了。只能靠手电筒了。"],
	],
	"floor_2.sound_event": [
		["", "——咚！！"],
		["sister", "（什么声音？！）", "scared"],
		["cool_npc", "……从电梯那个方向传来的。", "serious"],
		["cheerful_npc", "好响……好像有什么东西砸下来了……", "scared"],
	],
	"floor_2.cheerful_waiting": [
		["cheerful_npc", "等等我！发生什么了？！刚才那个声音——", "surprised"],
	],
	"floor_2.freeze_rescue": [
		["cool_npc", "不要动。", "serious"],
		["cheerful_npc", "什么？？", "surprised"],
		["cool_npc", "它跟的是你的脚步声。你停下来，它也会停。", "serious"],
		["cool_npc", "先站在原地别动。我们去找找有没有什么能帮你的东西。", "serious"],
		["cheerful_npc", "……好……我不动……你们快点回来……", "scared"],
	],
	"floor_2.cheerful_worried": [
		["cheerful_npc", "呜……你们找到什么了吗……", "crying"],
	],
	"floor_2.earplug_thanks": [
		["cheerful_npc", "呜呜……太可怕了……谢谢你们……", "crying"],
		["cool_npc", "电梯卡已经有了。走吧。", "serious"],
	],
	"floor_2.elevator_card_use": [
		["", "夏桐将电梯卡插入卡槽。"],
		["", "卡片被吸了进去——这一次，无法取出了。"],
		["", "电梯门打开。"],
	],
	"floor_2.elevator_no_earplug": [
		["sister", "鹿可！快过来，电梯在这边！"],
		["cheerful_npc", "我……我不敢动……万一那个声音又来了怎么办……", "scared"],
		["male_npc", "我把她抱过来怎么样？这样快一点。", "serious"],
		["sister", "不行！你抱着她的话，两个人都在移动……可能会同时被锁定。"],
		["sister", "鹿可，你听我说——一步一步的，慢慢走过来。不要跑。"],
		["cheerful_npc", "……好……我试试……", "scared"],
	],
	"floor_2.elevator_last_step": [
		["cheerful_npc", "不行了……我感觉我再走一步，高跟鞋就要踩下来了……", "scared"],
		["sister", "就差一步了！看着我，不要看别的地方！"],
	],
	"floor_2.elevator_pull_in": [
		["", "夏桐和林佳语同时伸手——一人一边，将鹿可拽进了电梯！"],
	],
	"floor_2.elevator_aftermath": [
		["", "咔哒——"],
		["", "巨大的高跟鞋狠狠踩在了电梯门外的地面上。"],
		["", "碎裂的地砖飞溅开来。鹿可的一只鞋还留在外面。"],
		["cheerful_npc", "呜……呜呜……我的鞋子……鞋子还在外面……", "crying"],
		["sister", "鞋子不要了。人没事就行。"],
		["cool_npc", "……再晚一秒就来不及了。", "serious"],
		["cheerful_npc", "谢谢你们……谢谢……", "crying"],
		["sister", "（……刚才伸手的时候，我和她的动作几乎完全同步。好像……很默契。）"],
	],
	"floor_2.elevator_up": [
		["", "按钮依然只有一个——向上。"],
		["", "没有人说话。"],
		["", "电梯缓缓上升……"],
	],
	"floor_2.talk_explore_cool": [
		["cool_npc", "别离电梯太远，也别让彼此脱离视线。这里安静得不正常。", "serious"],
	],
	"floor_2.talk_explore_cheerful": [
		["cheerful_npc", "要是这一层也有电梯卡就好了……我只想快点离开。", "nervous"],
	],
	"floor_2.talk_explore_male": [
		["male_npc", "先把电梯卡找到，再去找沈薇。她现在在气头上，未必肯听我。", "nervous"],
	],
	"floor_2.talk_explore_timid": [
		["timid_male", "你们去找电梯卡吧……我真的不敢再往里走了。", "scared"],
		["timid_male", "要是找到路了，回来喊我一声就行。", "nervous"],
	],
	"floor_2.talk_rule_discover_cool": [
		["cool_npc", "规则已经明了了。先把沈薇带回来，再晚就来不及了。", "serious"],
	],
	"floor_2.talk_rule_discover_male": [
		["male_npc", "薇薇，你可千万别出事……只要你还能听见就回我一声。", "scared"],
	],
	"floor_2.talk_rule_discover_female": [
		["female_npc", "我头顶那个声音一直没停！你们快点过来！", "scared"],
	],
	"floor_2.talk_cheerful_danger_cool": [
		["cool_npc", "先想办法让鹿可能活下来。能堵住声音、能骗过它的东西都别放过。", "serious"],
	],
	"floor_2.talk_cheerful_danger_male": [
		["male_npc", "我去翻近一点的房间。不能再少人了，绝对不能。", "serious"],
	],
	"floor_2.talk_search_cool": [
		["cool_npc", "保持队形。床底、柜子、书桌，一个都别漏。", "serious"],
	],
	"floor_2.talk_search_male": [
		["male_npc", "电梯卡应该就在附近。拿到就回电梯，别贪多。", "serious"],
	],
	"floor_2.talk_search_cheerful": [
		["cheerful_npc", "我会跟紧你们的……这次绝对不会掉队了。", "nervous"],
	],
	"floor_2.talk_done_cool": [
		["cool_npc", "卡已经够了。直接回电梯，不要在这层多停一秒。", "serious"],
	],
	"floor_2.talk_done_male": [
		["male_npc", "走，回电梯。只要别再分开，我们就还能活着上楼。", "serious"],
	],
	"floor_2.talk_done_cheerful": [
		["cheerful_npc", "我在，我跟着你们……别把我落下就行。", "nervous"],
	],

	# ============ 第三层 ============
	"floor_3.entry": [
		["", "电梯门打开的瞬间，一阵令人不适的气流从门缝中涌出。"],
		["", "全层的空气……黏稠得像是活的。"],
		["cheerful_npc", "地板……地板好像在动……你们看到了吗？", "scared"],
		["cool_npc", "小心脚下。不要踩到任何奇怪的东西。", "serious"],
		["male_npc", "电梯卡……只要找到电梯卡就能离开这鬼地方……", "nervous"],
	],
	"floor_3.entry2": [
		["", "走廊的尽头——"],
		["", "黑暗中，两点暗红色的光芒一闪一灭。"],
		["", "有什么东西……正站在那里。看着这边。"],
		["male_npc", "那……那是什么东西……！", "scared"],
		["cheerful_npc", "天哪……它是人吗？", "scared"],
		["cool_npc", "低头！不要和它对视！", "serious"],
		["cool_npc", "别动。不要发出声音。更不要跑。", "serious"],
	],
	"floor_3.male_panic": [
		["male_npc", "不行……不行不行不行——我不要死在这里！", "scared"],
		["male_npc", "沈薇死了、余凡也死了——我不想变成下一个！！", "scared"],
		["cool_npc", "不要跑！！", "serious"],
	],
	"floor_3.male_panic_run": [
		["", "他跑了出去——"],
		["cheerful_npc", "不要——！", "scared"],
	],
	"floor_3.male_panic_death": [
		["", "地板裂开了。"],
		["", "一张巨大的、漆黑的嘴从裂缝中猛然冲出——"],
		["", "将他整个人拽入了深渊。"],
		["", "连惨叫声都没来得及发出。"],
		["", "一切发生在不到一秒之内。"],
	],
	"floor_3.male_panic_aftermath": [
		["", "纸条上……又多了一行字。"],
		["sister", "（「禁止跑步」……跑步就会死……所以他才……）", "scared"],
		["cheerful_npc", "啊啊啊——不要……不要再死人了……", "crying"],
		["cool_npc", "冷静。跑就会被地板下面的东西吞掉。", "serious"],
		["cool_npc", "但那个东西——", "nervous"],
		["", "走廊尽头的人形怪物……正缓缓地、一步一步向这边走来。"],
		["cool_npc", "——它还在靠近。", "nervous"],
		["sister", "（不能跑……但也不能站在这里等死。先找到电梯卡。）", "serious"],
	],
	"floor_3.diary": [
		["", "地上有一本残破的日记本。大部分页面已经被撕掉了。"],
		["", "「……第三天了。它还在走廊里走。只要不跑就不会死……」"],
		["", "「……但它越来越近了。地板下面有东西。能听到呼吸声……」"],
		["", "「……不要跑……千万不要跑……地板下面的嘴——」"],
		["", "后面的字迹被干涸的血迹完全覆盖了。"],
		["sister", "（之前住在这里的人……也经历了同样的事……）", "sad"],
	],
	"floor_3.blood": [
		["cheerful_npc", "这……这些是血迹？到处都是……", "scared"],
		["cool_npc", "已经干了很久了。不是最近留下的。", "serious"],
		["sister", "（有人在这里挣扎过……但最终没能走出去。）", "sad"],
	],
	"floor_3.card_found": [
		["sister", "（拿到电梯卡了……但那个东西还在向这边走。）", "nervous"],
		["sister", "（我们走不了——它堵在电梯的方向。）", "nervous"],
		["sister", "（等一下……现在几点了？快七点了……）", "serious"],
		["sister", "（第一层的规则——「禁止对视」。林佳语说过对视会导致灵魂互换，七点就能换回来。）", "serious"],
		["sister", "（……如果我和那个怪物对视呢？）", "serious"],
		["sister", "（互换灵魂……我进入它的身体，操控它去跑步——）", "serious"],
		["sister", "（地板下面的怪物会把它吞掉！）", "serious"],
		["sister", "（然后撑到七点……灵魂就会自动回来！）", "serious"],
		["sister", "（现在已经快七点了，只要撑几分钟就行！）", "serious"],
		["sister", "（这是唯一的办法了。叫她们过来。）", "serious"],
	],
	"floor_3.card_found_norope": [
		["sister", "（拿到电梯卡了！）", "nervous"],
		["sister", "（那个东西还在后面追……不能跑，只能走。）", "nervous"],
		["sister", "（快走——趁它还没追上来！）", "serious"],
		["cool_npc", "拿到卡了？走，电梯在那边。", "serious"],
		["cheerful_npc", "求求了快一点……它越来越近了……", "scared"],
	],
	"floor_3.soul_swap_rope": [
		["sister", "听我说。你们两个过来，用绳子把我绑起来。", "serious"],
		["cool_npc", "……你想做什么。", "nervous"],
		["sister", "我要和那个东西对视。互换灵魂。用它的身体跑步引出地板下的怪物。", "serious"],
		["cheerful_npc", "你疯了吗？！万一回不来怎么办？！", "scared"],
		["sister", "七点灵魂就会回来。但是互换之后我的身体会失控，所以要绑住。", "serious"],
		["sister", "快过来……相信我。这是唯一的办法。", "nervous"],
		["", "林佳语沉默了几秒，接过绳子走了过来。"],
		["", "她和鹿可一起将夏桐牢牢地绑在了走廊的铁管上。"],
	],
	"floor_3.soul_swap_norope": [
		["sister", "你们两个抓住我的身体。不管发生什么，绝对不要松手。", "serious"],
		["cheerful_npc", "什、什么意思？！", "surprised"],
		["cool_npc", "……你要和它对视？", "nervous"],
		["sister", "嗯。用它的身体跑步，引出地板的怪物。", "serious"],
		["sister", "互换之后我的身体会被它控制，所以你们要按住我。", "nervous"],
		["", "夏桐深吸一口气。"],
		["", "林佳语和鹿可紧紧抓住了她。"],
	],
	"floor_3.perform_swap": [
		["", "夏桐抬起头——"],
		["", "直视那个正在缓步逼近的人形怪物。"],
		["", "四目相对。"],
		["", "……"],
		["", "世界翻转了。"],
	],
	"floor_3.perform_swap2": [
		["", "——视角变了。"],
		["", "夏桐发现自己站在了走廊的另一端。"],
		["", "低头——是一双漆黑的、布满裂纹的手。不属于人类的手。"],
		["", "灵魂互换成功了。"],
		["", "现在，她在怪物的躯体里。"],
		["sister", "（成功了……现在——跑！）", "serious"],
	],
	"floor_3.monster_run": [
		["sister", "（用这具身体跑！只要跑起来，地板下面的东西就会追上来！）", "scared"],
		["sister", "（撑到七点……灵魂就会回到我的身体里！）", "nervous"],
	],
	"floor_3.chase_caught": [
		["", "深渊巨口追上了——"],
		["", "漆黑的巨口一口咬住了这具身体！"],
		["", "但夏桐的灵魂还在里面……！"],
		["", "七点还没到……一切都结束了。"],
	],
	"floor_3.chase_survive": [
		["", "07:00。"],
		["", "仿佛被一只无形的手猛然拽出——"],
		["", "灵魂从正在被吞噬的躯体中弹射而回！"],
		["", "夏桐猛地睁开了眼睛。"],
		["", "她回到了自己的身体里。被绳子绑着的、安全完好的身体。"],
		["", "而走廊尽头的那个怪物——"],
		["", "连同它的躯体和里面被换过去的灵魂，一起被深渊巨口彻底吞噬了。"],
	],
	"floor_3.victory": [
		["cheerful_npc", "成……成功了……？真的成功了？！", "happy"],
		["cool_npc", "……", "serious"],
		["cool_npc", "走吧。去电梯。", "serious"],
		["sister", "……嗯。", "sad"],
	],
	"floor_3.enter_elevator_scene": [
		["sister", "快过来！电梯在这！", "nervous"],
		["", "夏桐颤抖着将电梯卡塞进卡槽。"],
		["", "咔——电梯门开了。"],
		["cool_npc", "进去！快！", "serious"],
	],
	"floor_3.player_run_death": [
		["", "脚步一加快的瞬间——"],
		["", "地板裂开了。"],
		["", "一张漆黑的巨口从脚下冲出——"],
	],
	"floor_3.talk_intro_cool": [
		["cool_npc", "脚下和墙里都不对劲。慢走，别碰黑的地方。", "serious"],
	],
	"floor_3.talk_intro_cheerful": [
		["cheerful_npc", "这里连空气都像黏在身上……我们拿到卡就立刻回电梯，好不好？", "scared"],
	],
	"floor_3.talk_intro_male": [
		["male_npc", "别磨蹭了，先找电梯卡。待得越久越危险。", "nervous"],
	],
	"floor_3.talk_explore_cool": [
		["cool_npc", "别跑，贴着我走。只要我们还在动脑子，就还有路。", "serious"],
	],
	"floor_3.talk_explore_cheerful": [
		["cheerful_npc", "我会慢慢走的……你别突然加速，我真的会被吓哭。", "crying"],
	],
	"floor_3.talk_escape_cool": [
		["cool_npc", "电梯就在前面。慢慢走，不要给地板下面的东西机会。", "serious"],
	],
	"floor_3.talk_escape_cheerful": [
		["cheerful_npc", "它还在后面吧……求你了，咱们就这样慢慢到电梯。", "scared"],
	],
	"floor_3.talk_victory_cool": [
		["cool_npc", "别松劲。离开第三层之前，什么都还没结束。", "serious"],
	],
	"floor_3.talk_victory_cheerful": [
		["cheerful_npc", "我们真的撑到天亮了……夏桐，你刚才真的吓死我了。", "crying"],
	],

	# ============ 结局过场电梯 ============
	"ending.elevator_alive_impact": [
		["", "砰——！"],
		["", "巨大的撞击声从门外传来。电梯微微震动。"],
		["cheerful_npc", "呜……呜呜……", "crying"],
		["cool_npc", "……没事了。它进不来。", "serious"],
	],
	"ending.elevator_alive_relief": [
		["", "又是一声撞击。这次轻了一些。"],
		["", "然后——安静了。"],
		["sister", "它……走了吗？"],
		["cool_npc", "不知道。但电梯在动了。", "serious"],
	],
	"ending.elevator_alive_descent": [
		["sister", "我妹妹也在这栋楼里……她不会也经历了这些吧……她不会已经……"],
		["cheerful_npc", "不会的！我们都活下来了，她肯定也可以的！", "happy"],
		["cool_npc", "说不定她已经逃出去了。这栋楼……不止一个出口。"],
		["", "电梯缓缓下降。"],
		["", "没有人再说话。"],
	],
	"ending.elevator_dead_reflection": [
		["cheerful_npc", "我们……真的能出去吗？", "scared"],
		["cool_npc", "电梯还在运行。至少说明还有路。", "serious"],
		["cheerful_npc", "已经死了那么多人了……为什么会变成这样……", "crying"],
		["cool_npc", "不知道。这栋公寓从一开始就不对劲。", "serious"],
	],
	"ending.elevator_dead_descent": [
		["sister", "我妹妹也在这栋楼里……她不会也经历了这些吧……她不会已经……"],
		["cheerful_npc", "不会的！我们都活下来了，她肯定也可以的！"],
		["cool_npc", "说不定她已经逃出去了。这栋楼……不止一个出口。"],
		["", "电梯缓缓下降。灯光微微闪了闪。"],
		["", "沉默中，只剩下机械运转的低沉嗡鸣。"],
	],
}

# ╔══════════════════════════════════════════╗
# ║     结局文本（非对话系统，逐行显示）       ║
# ╚══════════════════════════════════════════╝

const ENDING_TEXT := {
	"the_lie": "「 她 在 说 谎 」",
	"demo_end": "— Demo End —",
	"thanks": "《失序者的生存守则》\n\n感谢游玩",
}
