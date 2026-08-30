#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GODOT_BIN=${GODOT_BIN:-"$ROOT_DIR/Godot_v4.7.1-stable_linux.x86_64"}
QA_DIR="$ROOT_DIR/build/qa"
WEB_DIR="$ROOT_DIR/build/web"
ZIP_PATH="$ROOT_DIR/build/block-fighter-web-1.0.2.zip"
QA_TIMEOUT_SECONDS=${QA_TIMEOUT_SECONDS:-180}

mkdir -p "$QA_DIR" "$ROOT_DIR/build"

if [ ! -x "$GODOT_BIN" ]; then
	printf '%s\n' "Godot 4.7.1 binary not found: $GODOT_BIN" >&2
	exit 1
fi

GODOT_VERSION=$("$GODOT_BIN" --version 2>&1)
case "$GODOT_VERSION" in
	4.7.1.stable.official.*) ;;
	*)
		printf '%s\n' "Expected Godot 4.7.1, got: $GODOT_VERSION" >&2
		exit 1
		;;
esac

run_step() {
	step_name=$1
	shift
	log_path="$QA_DIR/$step_name.log"
	printf '[QA] %s\n' "$step_name"
	if timeout "$QA_TIMEOUT_SECONDS" "$@" >"$log_path" 2>&1; then
		return 0
	fi
	status=$?
	printf '[QA] %s failed (exit %s)\n' "$step_name" "$status" >&2
	tail -80 "$log_path" >&2 || true
	exit "$status"
}

check_test_log() {
	log_path=$1
	if grep -nE 'SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances were leaked|Resource still in use|resources still in use' "$log_path"; then
		printf '%s\n' "Disallowed test error in $log_path" >&2
		exit 1
	fi
}

run_step import "$GODOT_BIN" --headless --editor --path "$ROOT_DIR" --log-file "$QA_DIR/import-godot.log" --quit

run_step main_game_test "$GODOT_BIN" --headless --path "$ROOT_DIR" --log-file "$QA_DIR/main-game-godot.log" --script res://tests/main_game_test.gd
check_test_log "$QA_DIR/main_game_test.log"

run_step main_ui_test "$GODOT_BIN" --headless --path "$ROOT_DIR" --log-file "$QA_DIR/main-ui-godot.log" --script res://start_screen/tests/main_ui_test.gd
check_test_log "$QA_DIR/main_ui_test.log"

for test_path in \
	tests/hang_runtime_integration_test.gd \
	tests/corner_hang_runtime_integration_test.gd \
	tests/fall_runtime_integration_test.gd \
	tests/boxer_special_runtime_integration_test.gd \
	tests/cleaner_special_runtime_integration_test.gd \
	tests/firefighter_special_runtime_integration_test.gd \
	tests/chef_meat_runtime_integration_test.gd \
	tests/ninja_special_runtime_integration_test.gd
do
	step_name=$(basename "$test_path" .gd)
	run_step "$step_name" "$GODOT_BIN" --headless --path "$ROOT_DIR" --log-file "$QA_DIR/$step_name-godot.log" --script "res://$test_path"
	check_test_log "$QA_DIR/$step_name.log"
done

rm -rf "$WEB_DIR"
rm -f "$ZIP_PATH"
mkdir -p "$WEB_DIR"

run_step web_export "$GODOT_BIN" --headless --path "$ROOT_DIR" --log-file "$QA_DIR/web-export-godot.log" --export-release Web "$WEB_DIR/index.html"
if grep -nE 'SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances were leaked|Resource still in use|resources still in use' "$QA_DIR/web_export.log"; then
	printf '%s\n' "Disallowed export error in $QA_DIR/web_export.log" >&2
	exit 1
fi
if grep -nE 'Storing File: res://(tests|start_screen/tests|docs|tools|design|build|\.qa)/' "$QA_DIR/web_export.log"; then
	printf '%s\n' "Non-runtime source entered the Web export." >&2
	exit 1
fi

if ! (cd "$WEB_DIR" && zip -qr "$ZIP_PATH" . -x '*.import') >"$QA_DIR/package.log" 2>&1; then
	tail -80 "$QA_DIR/package.log" >&2 || true
	exit 1
fi
run_step package_check unzip -t "$ZIP_PATH"
if unzip -Z1 "$ZIP_PATH" | grep -Eq '(^|/)(tests|docs|tools|design)/'; then
	printf '%s\n' "Non-runtime source entered the Web ZIP." >&2
	exit 1
fi

HTTP_LOG="$QA_DIR/http_smoke.log"
python3 -m http.server 4173 --directory "$WEB_DIR" >"$HTTP_LOG" 2>&1 &
HTTP_PID=$!
cleanup_http() {
	kill "$HTTP_PID" >/dev/null 2>&1 || true
	wait "$HTTP_PID" >/dev/null 2>&1 || true
}
trap cleanup_http EXIT HUP INT TERM
http_ok=false
for _attempt in 1 2 3 4 5 6 7 8 9 10
do
	if curl -fsS http://127.0.0.1:4173/index.html >/dev/null 2>&1; then
		http_ok=true
		break
	fi
	sleep 1
done
if [ "$http_ok" != true ]; then
	tail -80 "$HTTP_LOG" >&2 || true
	exit 1
fi
trap - EXIT HUP INT TERM
cleanup_http

printf '%s\n' "QA PASS: Godot $GODOT_VERSION, game/UI/runtime tests, Web export, ZIP, and HTTP smoke."
printf '%s\n' "Logs: $QA_DIR"
