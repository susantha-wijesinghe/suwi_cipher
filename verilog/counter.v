module counter(
  input clk, rst_n, start, done,
  output[31:0] cycles
  );
  localparam [1:0] IDLE = 0,
                   CNT = 1,
                   DN = 2;
  reg [1:0] state, state_next;

  reg[31:0] cnt_reg, cnt_next;
  always@(posedge clk) begin
    if(!rst_n) begin
      state <= IDLE;
      cnt_reg <= 0;
    end
    else begin
      state <= state_next;
      cnt_reg <= cnt_next;
    end 
  end

  always@(*) begin 
    state_next = state;
    cnt_next = cnt_reg;
    case(state)
      IDLE: begin
        if(start==1) begin 
          state_next = CNT;
          cnt_next = 0;
        end  
      end
      CNT: begin
        if(done==1) begin 
          state_next = DN;
        end 
        else begin
          cnt_next = cnt_reg + 1'b1;
        end
      end  
      DN: begin
        state_next= IDLE;
      end 
      default: state_next = IDLE;
    endcase 
  end 
  assign cycles = cnt_reg;
endmodule