module fv_top #(parameter DW = 4, AW = 2) (
  input logic          wclk, wrst_n, rclk, rrst_n,
  input logic          winc, rinc, pwr_req, pick,
  input logic [DW-1:0] wdata,
  input logic [AW:0]   any_bin, any_ptr, any_s1, any_s2,
  input logic          any_full
);
  localparam int DEPTH = 1 << AW;
  logic          wfull, rempty, wen, writer_ok, pwr_on, iso_en, ret_save, ret_restore;
  logic [AW-1:0] waddr, raddr;
  logic [AW:0]   wptr, rptr;
  logic [DW-1:0] rdata;

`ifdef PA
  pwr_ctrl u_pc (.wclk, .wrst_n, .pwr_req, .writer_ok, .pwr_on, .iso_en, .ret_save, .ret_restore);
  fifo_wr_pa #(.AW(AW)) u_wr (.*);
`else
  assign {writer_ok, pwr_on, iso_en, ret_save, ret_restore} = 5'b11000;
  fifo_wr #(.AW(AW)) u_wr (.wclk, .wrst_n, .winc, .rptr, .wfull, .wen, .waddr, .wptr);
`endif
  fifo_rd #(.AW(AW)) u_rd (.rclk, .rrst_n, .rinc, .wptr, .rempty, .raddr, .rptr);
  fifo_mem #(.DW(DW), .AW(AW)) u_mem (.wclk, .wen, .waddr, .raddr, .wdata, .rdata);

  // ---- always-on reference model (independent of DUT pointers)
  wire push = wen;
  wire pop  = rinc && !rempty;
  logic [AW:0] ref_w, ref_r;
  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) ref_w <= '0; else if (push) ref_w <= ref_w + 1'b1;
  always_ff @(posedge rclk or negedge rrst_n)
    if (!rrst_n) ref_r <= '0; else if (pop) ref_r <= ref_r + 1'b1;
  wire [AW:0] occ = ref_w - ref_r;

  // ---- track one arbitrary write ("pick" lets the tool choose which)
  logic          trk, done;
  logic [AW:0]   trk_idx;
  logic [DW-1:0] trk_data;
  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) begin trk <= 1'b0; trk_idx <= '0; trk_data <= '0; end
    else if (push && pick && !trk) begin
      trk <= 1'b1; trk_idx <= ref_w; trk_data <= wdata;
    end
  wire hit = trk && !done && pop && (ref_r == trk_idx);
  always_ff @(posedge rclk or negedge rrst_n)
    if (!rrst_n) done <= 1'b0; else if (hit) done <= 1'b1;

  // ---- environment: producer only writes while the write domain is usable
  m_quiet: assume property (@(posedge wclk) disable iff (!wrst_n) !writer_ok |-> !winc);

  // ---- safety
  a_no_overflow:  assert property (@(posedge wclk) disable iff (!wrst_n) push |-> occ < DEPTH);
  a_no_underflow: assert property (@(posedge rclk) disable iff (!rrst_n) pop |-> occ != 0 && occ <= DEPTH);
  a_full_safe:    assert property (@(posedge wclk) disable iff (!wrst_n) occ == DEPTH |-> wfull);
  a_empty_safe:   assert property (@(posedge rclk) disable iff (!rrst_n) occ == 0 |-> rempty);
  a_data:         assert property (@(posedge rclk) disable iff (!rrst_n) hit |-> rdata == trk_data);
  a_wgray:        assert property (@(posedge wclk) disable iff (!wrst_n)
                    1'b1 |=> $onehot0(wptr ^ $past(wptr)));
  a_rgray:        assert property (@(posedge rclk) disable iff (!rrst_n)
                    1'b1 |=> $onehot0(rptr ^ $past(rptr)));
`ifdef PA
  a_iso_before_off: assert property (@(posedge wclk) disable iff (!wrst_n) !pwr_on |-> iso_en);
  a_off_blocks:     assert property (@(posedge wclk) disable iff (!wrst_n) !pwr_on |-> wfull && !wen);
  a_waddr_iso:      assert property (@(posedge wclk) disable iff (!wrst_n) iso_en |-> waddr == '0);
  a_wptr_held:      assert property (@(posedge wclk) disable iff (!wrst_n)
                      iso_en && $past(iso_en) |-> $stable(wptr));
`endif

  // ---- forward progress (formal only)
`ifndef SIM_CHECK
  m_reader_fair: assume property (@(posedge rclk) s_eventually rinc);
  a_delivered:   assert property (@(posedge rclk) disable iff (!rrst_n)
                   trk && !done |-> s_eventually done);
  a_full_clears: assert property (@(posedge wclk) disable iff (!wrst_n)
                   wfull && !iso_en |-> s_eventually (!wfull || iso_en));
`ifdef PA
  m_wake_fair: assume property (@(posedge wclk) s_eventually !pwr_req);
  a_wakes:     assert property (@(posedge wclk) disable iff (!wrst_n)
                 !pwr_on |-> s_eventually (pwr_on && !iso_en));
`endif
`endif

  // ---- covers: prove the proofs are not vacuous
  c_full:      cover property (@(posedge wclk) wfull && !iso_en);
  c_delivered: cover property (@(posedge rclk) done);
`ifndef SIM_CHECK
  c_wrap:      cover property (@(posedge wclk) ref_w == '1 ##[1:$] ref_w == 1);
`endif
`ifdef PA
  c_off_data:  cover property (@(posedge rclk) !pwr_on && pop);
`ifndef SIM_CHECK
  c_cycle:     cover property (@(posedge wclk) !pwr_on ##[1:$] pwr_on && !iso_en && push);
`endif
  c_full_off:  cover property (@(posedge wclk) !pwr_on && occ == DEPTH);
`endif
  // ---- extra functional coverage
  logic [1:0] pwr_cycles;   // restore count, saturates at 2
  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) pwr_cycles <= '0;
    else if (ret_restore && pwr_cycles != 2) pwr_cycles <= pwr_cycles + 2'd1;

  c_refill_empty:  cover property (@(posedge rclk) disable iff (!rrst_n) ref_r != 0 && occ == 0 && rempty);
  c_full_release:  cover property (@(posedge wclk) disable iff (!wrst_n) !wfull && $past(wfull) && !iso_en && !$past(iso_en));
  c_empty_release: cover property (@(posedge rclk) disable iff (!rrst_n) !rempty && $past(rempty));
  c_push_pop:      cover property (@(posedge wclk) disable iff (!wrst_n) push && pop);
`ifdef PA
  c_off_nonempty:  cover property (@(posedge wclk) disable iff (!wrst_n) !pwr_on && $past(pwr_on) && occ != 0);
  c_off_empty:     cover property (@(posedge wclk) disable iff (!wrst_n) !pwr_on && $past(pwr_on) && occ == 0);
  c_iso_when_full: cover property (@(posedge wclk) disable iff (!wrst_n) iso_en && !$past(iso_en) && occ == DEPTH);
  c_drain_off:     cover property (@(posedge rclk) disable iff (!rrst_n) !pwr_on && ref_w != 0 && occ == 0);
  c_two_cycles:    cover property (@(posedge wclk) disable iff (!wrst_n) pwr_cycles == 2 && writer_ok && push);
`endif
endmodule
