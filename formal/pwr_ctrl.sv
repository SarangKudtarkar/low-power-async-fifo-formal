// Legal power sequence with free timing: pwr_req=1 asks for power-down
module pwr_ctrl (
  input  logic wclk, wrst_n, pwr_req,
  output logic writer_ok, pwr_on, iso_en, ret_save, ret_restore
);
  typedef enum logic [2:0] {ON, QUIET, ISO, SAVE, OFF, WAKE, RESTORE, FLUSH} st_t;
  st_t st, nxt;
  logic [1:0] cnt;
  always_comb begin
    nxt = st;
    case (st)
      ON:      if (pwr_req)  nxt = QUIET;
      QUIET:                 nxt = ISO;
      ISO:                   nxt = SAVE;
      SAVE:                  nxt = OFF;
      OFF:     if (!pwr_req) nxt = WAKE;
      WAKE:    if (cnt == 2) nxt = RESTORE;
      RESTORE:               nxt = FLUSH;
      FLUSH:   if (cnt == 3) nxt = ON;
      default:               nxt = ON;
    endcase
  end
  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) begin st <= ON; cnt <= '0; end
    else begin st <= nxt; cnt <= (st != nxt) ? '0 : cnt + 2'd1; end

  assign writer_ok   = (st == ON) && !pwr_req;   // producer must be quiet otherwise
  assign pwr_on      = (st != OFF);
  assign iso_en      = !(st == ON || st == QUIET);
  assign ret_save    = (st == SAVE);
  assign ret_restore = (st == RESTORE);
endmodule
