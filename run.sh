#!/usr/bin/env bash
# Usage: ./run.sh [all|base|pwr|bug_iso|bug_ret]
# Env: JG (default "jg"), RATIOS (wclk:rclk clock factors), GUI=1
set -euo pipefail
cd "$(dirname "$0")"
MODE="${1:-all}"
case "$MODE" in all|base|pwr|bug_iso|bug_ret) ;; *) echo "usage: $0 [all|base|pwr|bug_iso|bug_ret]"; exit 2;; esac
JG="${JG:-jg}"
RATIOS="${RATIOS:-1:1 2:3 3:2}"
command -v "$JG" >/dev/null || { echo "$JG not found: source your Jasper setup or set JG=<path>"; exit 1; }
if [[ -n "${GUI:-}" && "$MODE" == all ]]; then echo "GUI=1 needs a single mode, e.g. GUI=1 $0 bug_iso"; exit 2; fi
mkdir -p logs work

RC=0
run_one() {  # task, "defines", expect(prove|cex)
  local task="$1" defs="$2" expect="$3" r wf rf tag log res
  for r in $RATIOS; do
    wf=${r%:*}; rf=${r#*:}; tag="${task}_${wf}_${rf}"; log="logs/$tag.log"
    rm -rf "work/$tag"
    local opts=(-proj "work/$tag")
    [[ -z "${GUI:-}" ]] && opts+=(-batch)
    FV_DEFS="$defs" WF="$wf" RF="$rf" "$JG" "${opts[@]}" -tcl formal/run.tcl 2>&1 | tee "$log" || true
    res=$(grep -E '^RESULT cex=' "$log" | tail -1 || true)
    if [[ -z "$res" ]]; then
      echo ">> $tag: ERROR, no result (see $log)" | tee -a logs/summary.txt; RC=1
    elif [[ "$expect" == prove && "$res" == "RESULT cex=0 undetermined=0 unreachable=0 uncovered_unknown=0" ]]; then
      echo ">> $tag: PROVEN" | tee -a logs/summary.txt
    elif [[ "$expect" == cex && "$res" != "RESULT cex=0 "* ]]; then
      echo ">> $tag: BUG CAUGHT [$res]" | tee -a logs/summary.txt
    else
      echo ">> $tag: CHECK [$res]" | tee -a logs/summary.txt; RC=1
    fi
  done
}

: > logs/summary.txt
want() { [[ "$MODE" == all || "$MODE" == "$1" ]]; }
if want base;    then run_one base    ""           prove; fi
if want pwr;     then run_one pwr     "PA"         prove; fi
if want bug_iso; then run_one bug_iso "PA BUG_ISO" cex;   fi
if want bug_ret; then run_one bug_ret "PA BUG_RET" cex;   fi
echo "================ SUMMARY"; cat logs/summary.txt
exit $RC
