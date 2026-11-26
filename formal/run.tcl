clear -all
set defs {}
foreach d $env(FV_DEFS) { lappend defs +define+$d }
analyze -sv12 {*}$defs rtl/fifo.sv formal/fifo_wr_pa.sv formal/pwr_ctrl.sv formal/fv_top.sv
elaborate -top fv_top
clock wclk -factor $env(WF) -phase 1
clock rclk -factor $env(RF) -phase 1
reset -expression {!wrst_n !rrst_n}
set_prove_time_limit 30m
prove -all
report
set cex   [get_property_list -include {type assert status cex}]
set undet [get_property_list -include {type assert status {undetermined unknown}}]
set unrch [get_property_list -include {type cover status unreachable}]
set uncov [get_property_list -include {type cover status {undetermined unknown}}]
puts "RESULT cex=[llength $cex] undetermined=[llength $undet] unreachable=[llength $unrch] uncovered_unknown=[llength $uncov]"
foreach p $cex { puts "RESULT_CEX $p" }
if {![info exists env(GUI)]} { exit -force }
