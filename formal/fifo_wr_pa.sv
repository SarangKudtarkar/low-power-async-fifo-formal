module fifo_wr_pa #(parameter AW = 4) (
  input  logic          wclk, wrst_n, winc,
  input  logic [AW:0]   rptr,
  input  logic          pwr_on, iso_en, ret_save, ret_restore,
  input  logic [AW:0]   any_bin, any_ptr, any_s1, any_s2,
  input  logic          any_full,
  output logic          wfull,
  output logic          wen,
  output logic [AW-1:0] waddr,
  output logic [AW:0]   wptr
);
  logic [AW:0] wbin, wptr_q, s1, s2, sv_bin, sv_ptr, iso_hold;
  logic        full_q, sv_full;
  wire         wen_i     = winc & ~full_q;
  wire [AW:0]  wbin_nxt  = wbin + {{AW{1'b0}}, wen_i};
  wire [AW:0]  wgray_nxt = (wbin_nxt >> 1) ^ wbin_nxt;

  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) begin
      wbin <= '0; wptr_q <= '0; full_q <= 1'b0; s1 <= '0; s2 <= '0;
    end else if (!pwr_on) begin            // everything in the domain is lost
      wbin <= any_bin; wptr_q <= any_ptr; full_q <= any_full;
      s1 <= any_s1; s2 <= any_s2;
    end else begin
      s1 <= rptr; s2 <= s1;                // synchroniser is not retained
      if (ret_restore) begin
`ifdef BUG_RET
        wbin <= '0;
`else
        wbin <= sv_bin;
`endif
        wptr_q <= sv_ptr; full_q <= sv_full;
      end else begin
        wbin <= wbin_nxt; wptr_q <= wgray_nxt;
        full_q <= (wgray_nxt == {~s2[AW:AW-1], s2[AW-2:0]});
      end
    end

  // always-on retention storage and isolation latch
  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) begin
      sv_bin <= '0; sv_ptr <= '0; sv_full <= 1'b0; iso_hold <= '0;
    end else begin
      if (ret_save) begin sv_bin <= wbin; sv_ptr <= wptr_q; sv_full <= full_q; end
      if (!iso_en) iso_hold <= wptr_q;
    end

`ifdef BUG_ISO
  assign wptr = iso_en ? '0 : wptr_q;
`else
  assign wptr = iso_en ? iso_hold : wptr_q;
`endif
  assign wfull = iso_en ? 1'b1 : full_q;
  assign wen   = iso_en ? 1'b0 : wen_i;
  assign waddr = iso_en ? '0   : wbin[AW-1:0];
endmodule
