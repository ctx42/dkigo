#!/usr/bin/env bash

# Run scripts in entrypoint directory.
echo "[C42] Running entrypoint scripts."
shopt -s nullglob
for SCRIPT in "$C42_CTR_ENTRYPOINT"/*.sh; do
	if [ -x "$SCRIPT" ]; then
		echo "[C42]  - running $SCRIPT"
		$SCRIPT || { echo "Error running: $SCRIPT"; exit 1; }
  else
		echo "[C42]  - CANNOT run non-executable $SCRIPT"
	fi
done
echo "[C42] Done running entrypoint scripts."
