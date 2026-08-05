GODOT ?= /opt/homebrew/bin/godot
PROJECT := .
MAIN_SCENE := scenes/ui/main_menu.tscn
PLAY_SCENE := scenes/play.tscn

.PHONY: help run play editor import startup test test-target clean-reports

help:
	@printf "Mountainhold commands:\n"
	@printf "  make run          Run the game from the main menu\n"
	@printf "  make play         Run the playable siege scene directly\n"
	@printf "  make editor       Open the project in the Godot editor\n"
	@printf "  make import       Run headless import/parser validation\n"
	@printf "  make startup      Run the startup smoke scene headless\n"
	@printf "  make test         Run all GdUnit4 tests\n"
	@printf "  make test-target TEST=res://test/enemy_test.gd\n"
	@printf "  make clean-reports Remove GdUnit4 reports\n"

run:
	"$(GODOT)" --path "$(PROJECT)" "$(MAIN_SCENE)"

play:
	"$(GODOT)" --path "$(PROJECT)" "$(PLAY_SCENE)"

editor:
	"$(GODOT)" --path "$(PROJECT)" --editor

import:
	"$(GODOT)" --headless --path "$(PROJECT)" --import --quit-after 1

startup:
	"$(GODOT)" --headless --path "$(PROJECT)" scenes/test/project_startup_test.tscn --quit-after 90

test:
	GODOT_BIN="$(GODOT)" bash addons/gdUnit4/runtest.sh -a res://test

test-target:
	@test -n "$(TEST)" || (printf "Usage: make test-target TEST=res://test/enemy_test.gd\n" && exit 2)
	GODOT_BIN="$(GODOT)" bash addons/gdUnit4/runtest.sh -a "$(TEST)"

clean-reports:
	rm -rf reports
