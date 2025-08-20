// ================================================================
// MiniMIPS-style ALU (STRUCTURAL) - synthesizable
// ================================================================
`timescale 1ns/1ps

// ---------------------------
// Utility multiplexers
// ---------------------------
module mux2 #(parameter WIDTH=32)(
  input  logic [WIDTH-1:0] a, b,
  input  logic sel,
  output logic [WIDTH-1:0] y
);
  assign y = sel ? b : a;
endmodule

module mux4 #(parameter WIDTH=32)(
  input  logic [WIDTH-1:0] d0, d1, d2, d3,
  input  logic [1:0]       sel,
  output logic [WIDTH-1:0] y
);
  always_comb begin
    unique case(sel)
      2'b00: y = d0;
      2'b01: y = d1;
      2'b10: y = d2;
      2'b11: y = d3;
    endcase
  end
endmodule

// ---------------------------
// Shifter: 00 no, 01 LSL, 10 LSR, 11 ASR
// ---------------------------
module shifter #(parameter WIDTH=32)(
  input  logic [WIDTH-1:0] a,
  input  logic [4:0]       shamt,
  input  logic [1:0]       func,
  output logic [WIDTH-1:0] y
);
  logic [WIDTH-1:0] no_s, lsl, lsr, asr;
  assign no_s = a;
  assign lsl  = a <<  shamt;
  assign lsr  = a >>  shamt;
  assign asr  = $signed(a) >>> shamt;
  mux4 #(WIDTH) u_mux(.d0(no_s), .d1(lsl), .d2(lsr), .d3(asr), .sel(func), .y(y));
endmodule

// ---------------------------
// Logic unit: 00 AND, 01 OR, 10 XOR, 11 NOR
// ---------------------------
module logic_unit #(parameter WIDTH=32)(
  input  logic [WIDTH-1:0] a, b,
  input  logic [1:0]       func,
  output logic [WIDTH-1:0] y
);
  logic [WIDTH-1:0] and_y, or_y, xor_y, nor_y;
  assign and_y = a & b;
  assign or_y  = a | b;
  assign xor_y = a ^ b;
  assign nor_y = ~(a | b);
  mux4 #(WIDTH) u_mux(.d0(and_y), .d1(or_y), .d2(xor_y), .d3(nor_y), .sel(func), .y(y));
endmodule

// ---------------------------
// Adder/Subtractor with signed overflow flag
// add_sub: 0=add, 1=sub
// ---------------------------
module addsub #(parameter WIDTH=32)(
  input  logic [WIDTH-1:0] a, b,
  input  logic             add_sub,
  output logic [WIDTH-1:0] sum,
  output logic             ovfl
);
  logic [WIDTH-1:0] b_eff;
  logic [WIDTH:0]   res_ext;

  assign b_eff  = add_sub ? ~b + 1'b1 : b;   // two's complement for subtraction
  assign res_ext = {a[WIDTH-1], a} + {b_eff[WIDTH-1], b_eff};
  assign sum     = res_ext[WIDTH-1:0];

  // signed overflow detection
  always_comb begin
    if (!add_sub) begin // add
      ovfl = ( a[WIDTH-1] == b[WIDTH-1] ) && ( sum[WIDTH-1] != a[WIDTH-1] );
    end else begin      // sub (a + (~b+1))
      ovfl = ( a[WIDTH-1] != b[WIDTH-1] ) && ( sum[WIDTH-1] != a[WIDTH-1] );
    end
  end
endmodule

// ---------------------------
// Signed SLT (Set-Less-Than) => 32'b...0001 or 0
// ---------------------------
module slt_signed #(parameter WIDTH=32)(
  input  logic [WIDTH-1:0] a, b,
  output logic [WIDTH-1:0] y
);
  logic less;
  assign less = ($signed(a) < $signed(b));
  assign y    = {{(WIDTH-1){1'b0}}, less};
endmodule

// ---------------------------
// Zero flag as 32-input NOR (reduction NOR)
// ---------------------------
module zero_flag #(parameter WIDTH=32)(
  input  logic [WIDTH-1:0] d,
  output logic             z
);
  assign z = ~(|d);
endmodule

// ---------------------------
// Top ALU (structural composition)
// ---------------------------
module alu_sv#(parameter WIDTH=32)(
  input  logic [WIDTH-1:0] x, y,
  input  logic [1:0]       shift_func,     // 00 no, 01 LSL, 10 LSR, 11 ASR
  input  logic [1:0]       logic_func,     // 00 AND, 01 OR, 10 XOR, 11 NOR
  input  logic [1:0]       func_class,     // 00 Shift, 01 SLT, 10 Arithmetic, 11 Logic
  input  logic             add_sub,        // 0 add, 1 sub
  input  logic             const_var,      // 0 use const_amt, 1 use x[4:0]
  input  logic [4:0]       const_amt,
  output logic [WIDTH-1:0] s,
  output logic             zero,
  output logic             ovfl
);

  // Shift amount select
  logic [4:0] shamt;
  logic [4:0] x_lsb;
  assign x_lsb = x[4:0];
  mux2 #(5) u_shamt_sel(.a(const_amt), .b(x_lsb), .sel(const_var), .y(shamt));

  // Block outputs
  logic [WIDTH-1:0] shift_y, logic_y, add_y, slt_y;

  shifter     #(WIDTH) u_shifter(.a(y), .shamt(shamt), .func(shift_func), .y(shift_y));
  logic_unit  #(WIDTH) u_logic  (.a(x), .b(y), .func(logic_func), .y(logic_y));
  addsub      #(WIDTH) u_addsub (.a(x), .b(y), .add_sub(add_sub), .sum(add_y), .ovfl(ovfl));
  slt_signed  #(WIDTH) u_slt    (.a(x), .b(y), .y(slt_y));

  // Result select by function class
  mux4 #(WIDTH) u_result_sel(
    .d0(shift_y), .d1(slt_y), .d2(add_y), .d3(logic_y),
    .sel(func_class), .y(s)
  );

  // Zero flag
  zero_flag #(WIDTH) u_zero(.d(s), .z(zero));

endmodule
