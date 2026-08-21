class_name RbMainMenuUi
extends Control
## rebuild 主菜单。
##
## 脚本只做三件事：重置状态、连按钮信号、请求切场景。
## 标题文案、字号、配色、按钮排布全部在 rb_main_menu.tscn 里。

@onready var _new_game_button: Button = $Layout/Buttons/NewGameButton
@onready var _quit_button: Button = $Layout/Buttons/QuitButton


func _ready() -> void:
	RbGameState.set_state(RbGameState.State.MENU)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	RbGameState.reset_for_new_game()
	RbSceneLoader.change_to(self, RbSceneRegistry.PROLOGUE_STREET, "default")


func _on_quit_pressed() -> void:
	get_tree().quit()
