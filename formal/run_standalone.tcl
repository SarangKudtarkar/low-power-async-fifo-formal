# Standalone Jasper run for the low-power async FIFO (no environment variables)
# Run from : repository root
#            jg -tcl formal/run_standalone.tcl

# ---------------- edit these ----------------
set CONFIG pwr   ;# base | pwr | bug_iso | bug_ret
set WF     1     ;# wclk factor
set RF     1     ;# rclk factor
# --------------------------------------------

switch -- $CONFIG {
  base    { set defs {} }
  pwr     { set defs {+define+PA} }
  bug_iso { set defs {+define+PA +define+BUG_ISO} }
  bug_ret { set defs {+define+PA +define+BUG_RET} }
  default { error "CONFIG must be base, pwr, bug_iso or bug_ret" }
}

set files {rtl/fifo.sv formal/fifo_wr_pa.sv formal/pwr_ctrl.sv formal/fv_top.sv}
foreach f $files {
  if {![file exists $f]} { error "$f not found: start jg from the repository root" }
}

clear -all
analyze -sv12 {*}$defs {*}$files
elaborate -top fv_top

clock wclk -factor $WF -phase 1
clock rclk -factor $RF -phase 1
reset -expression {!wrst_n !rrst_n}

set_prove_time_limit 30m
prove -all
report

puts "DONE: CONFIG=$CONFIG wclk:rclk factors=$WF:$RF"
