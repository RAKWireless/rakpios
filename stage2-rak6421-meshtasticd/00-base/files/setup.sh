#!/bin/bash
# Meshtastic setup for RAK6421 Pi-Hat + RAK1906
# Phase 0: meshtasticd service health check
# Phase 1: UART / meshtasticd config.yaml
# Phase 2: Meshtastic CLI (telemetry, GPS) — one setting at a time

set -uo pipefail

SETTLE_SEC=10
MAX_RETRIES=3
FAILED=0

# ── output helpers ────────────────────────────────────────────────────────────

section() { echo ""; echo "== $1 =="; echo ""; }
step()    { printf "  %-48s " "$1"; }
ok()      { echo "OK  ($1)"; }
skip()    { echo "SKIP ($1)"; }
fail()    { echo "FAIL ($1)"; FAILED=1; }
warn()    { echo "  ! $1"; }

# Meshtastic CLI is often installed to ~/.local/bin (user pip). sudo resets PATH
# and Python site-packages, so run CLI as the invoking user when elevated.
CLI_USER="${SUDO_USER:-${USER:-rak}}"
CLI_HOME=$(getent passwd "$CLI_USER" 2>/dev/null | cut -d: -f6)
CLI_HOME="${CLI_HOME:-/home/${CLI_USER}}"

resolve_meshtastic_cmd() {
	local cand
	for cand in \
		"$(command -v meshtastic 2>/dev/null)" \
		"${CLI_HOME}/.local/bin/meshtastic" \
		/usr/local/bin/meshtastic \
		/usr/bin/meshtastic; do
		[ -n "$cand" ] && [ -x "$cand" ] && { echo "$cand"; return 0; }
	done
	return 1
}

run_meshtastic() {
	local cli_path="${MESHTASTIC_CMD:?meshtastic CLI not resolved}"
	local cli_env="PATH=${CLI_HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"

	if [ "$(id -u)" -eq 0 ] && [ "$CLI_USER" != "root" ]; then
		sudo -u "$CLI_USER" env "$cli_env" "$cli_path" "$@"
	else
		env "$cli_env" "$cli_path" "$@"
	fi
}

run_systemctl() {
	if [ "$(id -u)" -eq 0 ]; then
		systemctl "$@"
	else
		sudo systemctl "$@"
	fi
}

MESHTASTICD_UNIT="meshtasticd.service"

# Returns 0 when meshtasticd.service is enabled, active, and CLI can reach it.
check_meshtasticd_service() {
	local since=""

	step "meshtasticd unit"
	if ! run_systemctl cat "$MESHTASTICD_UNIT" &>/dev/null; then
		fail "unit not found (is meshtasticd installed?)"
		return 1
	fi
	ok "installed"

	step "meshtasticd enabled"
	if run_systemctl is-enabled --quiet "$MESHTASTICD_UNIT"; then
		ok "enabled"
	else
		warn "not enabled — enabling..."
		if run_systemctl enable "$MESHTASTICD_UNIT" &>/dev/null; then
			ok "enabled"
		else
			fail "systemctl enable failed"
			return 1
		fi
	fi

	step "meshtasticd running"
	if ! run_systemctl is-active --quiet "$MESHTASTICD_UNIT"; then
		warn "not running — starting..."
		run_systemctl start "$MESHTASTICD_UNIT" &>/dev/null || true
		sleep 10
	fi
	if run_systemctl is-active --quiet "$MESHTASTICD_UNIT"; then
		since=$(run_systemctl show "$MESHTASTICD_UNIT" --property=ActiveEnterTimestamp --value 2>/dev/null || true)
		ok "active${since:+ (since ${since})}"
	else
		fail "not active — run: sudo systemctl status ${MESHTASTICD_UNIT}"
		return 1
	fi

	step "meshtasticd CLI reachability"
	MESHTASTIC_CMD=$(resolve_meshtastic_cmd || true)
	if [ -z "$MESHTASTIC_CMD" ]; then
		fail "meshtastic CLI not installed"
		warn "install: pip3 install \"meshtastic[cli]\" --break-system-packages"
		return 1
	fi
	if run_meshtastic --info &>/dev/null; then
		ok "connected"
	else
		fail "CLI cannot reach meshtasticd"
		warn "check: sudo journalctl -u ${MESHTASTICD_UNIT} -n 30 --no-pager"
		return 1
	fi

	return 0
}

# Restart meshtasticd after config.yaml changes and wait until CLI can connect.
restart_meshtasticd_and_wait() {
	local attempt=1
	local max_attempts=6

	step "meshtasticd restart"
	if ! run_systemctl restart "$MESHTASTICD_UNIT" &>/dev/null; then
		fail "systemctl restart failed"
		return 1
	fi

	while [ "$attempt" -le "$max_attempts" ]; do
		sleep "$SETTLE_SEC"
		if run_systemctl is-active --quiet "$MESHTASTICD_UNIT" && \
		   run_meshtastic --info &>/dev/null; then
			ok "ready"
			return 0
		fi
		attempt=$((attempt + 1))
	done

	fail "not reachable after restart (${max_attempts}x${SETTLE_SEC}s)"
	return 1
}

print_summary() {
	section "Summary"

	if [ "$FAILED" -eq 0 ]; then
		echo "  All steps completed successfully."
	else
		echo "  One or more steps failed — review output above."
	fi

	echo ""
	echo "  Telemetry : environment on (1800s), RAK1906/RAK1901 sensors"
	echo "  Position  : GPS enabled, smart broadcast off"
	echo ""
	echo "  Next: docker compose -f ~/meshmonitor/meshmonitor-docker-compose.yaml up -d"
	echo ""
}

# ── Phase 0: meshtasticd service ─────────────────────────────────────────────

section "Phase 0 — meshtasticd service"

if ! check_meshtasticd_service; then
	print_summary
	exit 1
fi

# ── Phase 1: serial port & meshtasticd config.yaml ──────────────────────────

section "Phase 1 — Serial port & meshtasticd"

echo "Enabling UART, disabling serial console..."
sudo raspi-config nonint do_serial_hw 0
sudo raspi-config nonint do_serial_cons 1
step "UART hardware";        ok "enabled"
step "Serial console";       ok "disabled"

CONFIG_YAML="/etc/meshtasticd/config.yaml"
CONFIG_YAML_CHANGED=0
if [ ! -f "$CONFIG_YAML" ]; then
	step "meshtasticd config.yaml"; skip "not found"
else
	changed=()

	if grep -q '^#  I2CDevice: /dev/i2c-1' "$CONFIG_YAML"; then
		sudo sed -i 's/^#  I2CDevice: \/dev\/i2c-1/  I2CDevice: \/dev\/i2c-1/' "$CONFIG_YAML"
		changed+=(I2CDevice)
	fi

	SERIAL_DEVICE="/dev/ttyS0"
	if [ -f /sys/firmware/devicetree/base/model ]; then
		if grep -qi "Raspberry Pi 5" /sys/firmware/devicetree/base/model; then
			SERIAL_DEVICE="/dev/ttyAMA0"
		fi
	fi

	if grep -q '^#  SerialPath: /dev/tty' "$CONFIG_YAML"; then
		sudo sed -i "s|^#  SerialPath: /dev/tty[A-Z0-9]*|  SerialPath: ${SERIAL_DEVICE}|" "$CONFIG_YAML"
		changed+=("SerialPath=${SERIAL_DEVICE}")
	fi

	if grep -q '^#  Port: 9443' "$CONFIG_YAML"; then
		sudo sed -i 's/^#  Port: 9443/  Port: 9443/' "$CONFIG_YAML"
		changed+=("Port=9443")
	fi

	if [ ${#changed[@]} -gt 0 ]; then
		step "meshtasticd config.yaml"; ok "${changed[*]}"
		CONFIG_YAML_CHANGED=1
	else
		step "meshtasticd config.yaml"; skip "already configured"
	fi
fi

if [ "$CONFIG_YAML_CHANGED" -eq 1 ]; then
	if ! restart_meshtasticd_and_wait; then
		print_summary
		exit 1
	fi
fi

warn "Reboot required for serial port changes to take effect."

# ── Phase 2: Meshtastic CLI ─────────────────────────────────────────────────

section "Phase 2 — Meshtastic CLI settings"

# Resolved in Phase 0; re-resolve if script is edited to skip Phase 0 later.
MESHTASTIC_CMD="${MESHTASTIC_CMD:-$(resolve_meshtastic_cmd || true)}"
if [ -z "$MESHTASTIC_CMD" ]; then
	step "meshtastic CLI"
	fail "not installed (pip3 install \"meshtastic[cli]\" --break-system-packages)"
	print_summary
	exit 1
fi

step "meshtastic CLI"
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
	ok "${MESHTASTIC_CMD} (run as ${CLI_USER})"
else
	ok "${MESHTASTIC_CMD}"
fi

# Format: "key|set_value|expected_get_value"
CONFIG_ITEMS=(
	"telemetry.environment_measurement_enabled|true|True"
	"telemetry.environment_update_interval|1800|1800"
	"position.gps_mode|ENABLED|1"
	"position.position_broadcast_smart_enabled|false|False"
)

get_config_value() {
	local key="$1"
	local escaped
	escaped=$(echo "$key" | sed 's/\./\\./g')
	run_meshtastic --get "$key" 2>/dev/null | sed -n "s/^${escaped}: *//p" | head -1
}

parse_config_from_output() {
	local output="$1" key="$2"
	local escaped
	escaped=$(echo "$key" | sed 's/\./\\./g')
	echo "$output" | sed -n "s/^${escaped}: *//p" | head -1
}

# Read all config keys in one pass before writing anything.
declare -A CURRENT_CONFIG=()

prefetch_current_state() {
	local get_args=() output item key

	for item in "${CONFIG_ITEMS[@]}"; do
		IFS='|' read -r key _ _ <<< "$item"
		get_args+=( "--get" "$key" )
	done

	echo "Reading current settings..."
	output=$(run_meshtastic "${get_args[@]}" 2>/dev/null || true)
	for item in "${CONFIG_ITEMS[@]}"; do
		IFS='|' read -r key _ _ <<< "$item"
		CURRENT_CONFIG[$key]=$(parse_config_from_output "$output" "$key")
	done
	echo ""
}

apply_config_item() {
	local key="$1" set_val="$2" expected="$3"
	local attempt=1 got=""

	while [ "$attempt" -le "$MAX_RETRIES" ]; do
		if ! run_meshtastic --set "$key" "$set_val" &>/dev/null; then
			attempt=$((attempt + 1))
			[ "$attempt" -le "$MAX_RETRIES" ] && sleep "$SETTLE_SEC"
			continue
		fi

		sleep "$SETTLE_SEC"
		got=$(get_config_value "$key")

		if [ "$got" = "$expected" ]; then
			ok "$got"
			return 0
		fi

		attempt=$((attempt + 1))
		[ "$attempt" -le "$MAX_RETRIES" ] && sleep "$SETTLE_SEC"
	done

	fail "expected ${expected}, got ${got:-empty} (${MAX_RETRIES} tries)"
	return 1
}

prefetch_current_state

total=${#CONFIG_ITEMS[@]}
idx=0
need_apply=0
already_ok=0

for item in "${CONFIG_ITEMS[@]}"; do
	IFS='|' read -r key set_val expected <<< "$item"
	current="${CURRENT_CONFIG[$key]:-}"
	if [ "$current" = "$expected" ]; then
		already_ok=$((already_ok + 1))
	else
		need_apply=$((need_apply + 1))
	fi
done

if [ "$need_apply" -eq 0 ]; then
	echo "All ${total} settings already match — nothing to write."
	echo ""
else
	echo "${already_ok}/${total} already correct, ${need_apply} to apply (${SETTLE_SEC}s settle after each write)"
	echo ""
fi

for item in "${CONFIG_ITEMS[@]}"; do
	IFS='|' read -r key set_val expected <<< "$item"
	current="${CURRENT_CONFIG[$key]:-}"
	idx=$((idx + 1))
	printf "[%d/%d] " "$idx" "$total"
	step "$key"
	if [ "$current" = "$expected" ]; then
		skip "already ${expected}"
		continue
	fi
	apply_config_item "$key" "$set_val" "$expected" || true
done

print_summary
exit "$FAILED"
