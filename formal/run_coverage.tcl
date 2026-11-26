# Jasper formal coverage for the low-power async FIFO
# Run from : repository root
#            jg -tcl formal/run_coverage.tcl
# Needs Coverage app access. check_cov options can differ between versions.

# ---------------- edit these ----------------
set CONFIG pwr   ;# base | pwr  (do not collect coverage on bug runs)
set WF     1     ;# wclk factor
set RF     1     ;# rclk factor
# --------------------------------------------

switch -- $CONFIG {
  base    { set defs {} }
  pwr     { set defs {+define+PA} }
  default { error "CONFIG must be base or pwr" }
}
set files {rtl/fifo.sv formal/fifo_wr_pa.sv formal/pwr_ctrl.sv formal/fv_top.sv}
foreach f $files {
  if {![file exists $f]} { error "$f not found: start jg from the repository root" }
}

clear -all
check_cov -init -type all -model {branch statement toggle}
analyze -sv12 {*}$defs {*}$files
elaborate -top fv_top

clock wclk -factor $WF -phase 1
clock rclk -factor $RF -phase 1
reset -expression {!wrst_n !rrst_n}

set_prove_time_limit 30m
prove -all

check_cov -measure -type {stimuli coi proof}

file mkdir logs
set rpt logs/coverage_${CONFIG}_${WF}_${RF}.rpt
check_cov -report -force -report_file $rpt
report

puts "DONE: review $rpt, assertion results and cover results"
