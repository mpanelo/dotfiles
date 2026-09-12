#!/usr/bin/env bash

# Return success when this machine exposes a battery.
if command -v pmset >/dev/null 2>&1 && pmset -g batt 2>/dev/null | grep -q '%'; then
	exit 0
fi

if command -v acpi >/dev/null 2>&1 && acpi -b 2>/dev/null | grep -q '%'; then
	exit 0
fi

if command -v upower >/dev/null 2>&1 && upower -e 2>/dev/null | grep -qi battery; then
	exit 0
fi

if command -v termux-battery-status >/dev/null 2>&1 && termux-battery-status >/dev/null 2>&1; then
	exit 0
fi

if command -v apm >/dev/null 2>&1 && apm -l >/dev/null 2>&1; then
	exit 0
fi

for battery in /sys/class/power_supply/BAT*; do
	if [ -e "$battery" ]; then
		exit 0
	fi
done

exit 1
