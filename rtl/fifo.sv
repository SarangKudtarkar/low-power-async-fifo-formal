module sync_2ff #(parameter W = 5) (
  input  logic         clk, rst_n,
  input  logic [W-1:0] d,
  output logic [W-1:0] q
);
  logic [W-1:0] m;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) {q, m} <= '0;
    else        {q, m} <= {m, d};
endmodule

module fifo_wr #(parameter AW = 4) (
  input  logic          wclk, wrst_n, winc,
  input  logic [AW:0]   rptr,
  output logic          wfull,
  output logic          wen,
  output logic [AW-1:0] waddr,
  output logic [AW:0]   wptr
);
  logic [AW:0] wbin, wbin_nxt, wgray_nxt, wq2_rptr;
  sync_2ff #(.W(AW+1)) u_sync_r2w (.clk(wclk), .rst_n(wrst_n), .d(rptr), .q(wq2_rptr));
  assign wen       = winc & ~wfull;
  assign waddr     = wbin[AW-1:0];
  assign wbin_nxt  = wbin + {{AW{1'b0}}, wen};
  assign wgray_nxt = (wbin_nxt >> 1) ^ wbin_nxt;
  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) begin
      wbin <= '0; wptr <= '0; wfull <= 1'b0;
    end else begin
      wbin  <= wbin_nxt;
      wptr  <= wgray_nxt;
      wfull <= (wgray_nxt == {~wq2_rptr[AW:AW-1], wq2_rptr[AW-2:0]});
    end
endmodule

module fifo_rd #(parameter AW = 4) (
  input  logic          rclk, rrst_n, rinc,
  input  logic [AW:0]   wptr,
  output logic          rempty,
  output logic [AW-1:0] raddr,
  output logic [AW:0]   rptr
);
  logic [AW:0] rbin, rbin_nxt, rgray_nxt, rq2_wptr;
  sync_2ff #(.W(AW+1)) u_sync_w2r (.clk(rclk), .rst_n(rrst_n), .d(wptr), .q(rq2_wptr));
  assign raddr     = rbin[AW-1:0];
  assign rbin_nxt  = rbin + {{AW{1'b0}}, (rinc & ~rempty)};
  assign rgray_nxt = (rbin_nxt >> 1) ^ rbin_nxt;
  always_ff @(posedge rclk or negedge rrst_n)
    if (!rrst_n) begin
      rbin <= '0; rptr <= '0; rempty <= 1'b1;
    end else begin
      rbin   <= rbin_nxt;
      rptr   <= rgray_nxt;
      rempty <= (rgray_nxt == rq2_wptr);
    end
endmodule

module fifo_mem #(parameter DW = 8, AW = 4) (
  input  logic          wclk, wen,
  input  logic [AW-1:0] waddr, raddr,
  input  logic [DW-1:0] wdata,
  output logic [DW-1:0] rdata
);
  logic [DW-1:0] mem [0:(1<<AW)-1];
  always_ff @(posedge wclk) if (wen) mem[waddr] <= wdata;
  assign rdata = mem[raddr];
endmodule
