`timescale 1ns/1ps

// -----------------------------
// DUT: Simple ALU (example)
// -----------------------------
module alu #(parameter WIDTH = 8)(
    input  logic [WIDTH-1:0] a, b,
    input  logic [2:0]       opcode,   // 3-bit opcode
    output logic [WIDTH-1:0] result,
    output logic             zero
);

    always_comb begin
        case(opcode)
            3'b000: result = a + b;      // ADD
            3'b001: result = a - b;      // SUB
            3'b010: result = a & b;      // AND
            3'b011: result = a | b;      // OR
            3'b100: result = a ^ b;      // XOR
            3'b101: result = ~a;         // NOT
            3'b110: result = a << 1;     // Shift Left
            3'b111: result = a >> 1;     // Shift Right
            default: result = '0;
        endcase
    end

    assign zero = (result == 0);

endmodule


// -----------------------------
// Transaction
// -----------------------------
class transaction;
    rand logic [7:0] a, b;
    rand logic [2:0] opcode;
    logic [7:0] exp_result;
    logic exp_zero;

    // Prediction method
    function void predict();
        case(opcode)
            3'b000: exp_result = a + b;
            3'b001: exp_result = a - b;
            3'b010: exp_result = a & b;
            3'b011: exp_result = a | b;
            3'b100: exp_result = a ^ b;
            3'b101: exp_result = ~a;
            3'b110: exp_result = a << 1;
            3'b111: exp_result = a >> 1;
            default: exp_result = 0;
        endcase
        exp_zero = (exp_result == 0);
    endfunction
endclass


// -----------------------------
// Generator
// -----------------------------
class generator;
    mailbox gen2drv;
    int num_tests;

    function new(mailbox gen2drv, int num_tests=20);
        this.gen2drv = gen2drv;
        this.num_tests = num_tests;
    endfunction

    task run();
        transaction tr;
        repeat(num_tests) begin
            tr = new();
            assert(tr.randomize());
            tr.predict();
            gen2drv.put(tr);
        end
    endtask
endclass


// -----------------------------
// Driver
// -----------------------------
class driver;
    mailbox gen2drv;
    virtual alu_if vif;

    function new(mailbox gen2drv, virtual alu_if vif);
        this.gen2drv = gen2drv;
        this.vif     = vif;
    endfunction

    task run();
        transaction tr;
        forever begin
            gen2drv.get(tr);
            vif.a      <= tr.a;
            vif.b      <= tr.b;
            vif.opcode <= tr.opcode;
            #5; // wait for result
        end
    endtask
endclass


// -----------------------------
// Monitor
// -----------------------------
class monitor;
    virtual alu_if vif;
    mailbox mon2scb;

    function new(virtual alu_if vif, mailbox mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        transaction tr;
        forever begin
            #5;
            tr = new();
            tr.a = vif.a;
            tr.b = vif.b;
            tr.opcode = vif.opcode;
            tr.exp_result = vif.result;
            tr.exp_zero   = vif.zero;
            mon2scb.put(tr);
        end
    endtask
endclass


// -----------------------------
// Scoreboard
// -----------------------------
class scoreboard;
    mailbox mon2scb;
    int fd;

    function new(mailbox mon2scb);
        this.mon2scb = mon2scb;
        fd = $fopen("alu_results.txt", "w");
        if (!fd) $display("ERROR: Could not open results file.");
    endfunction

    task run();
        transaction tr;
        logic [7:0] golden;
        logic gold_zero;

        forever begin
            mon2scb.get(tr);
            // Golden model recomputation
            case(tr.opcode)
                3'b000: golden = tr.a + tr.b;
                3'b001: golden = tr.a - tr.b;
                3'b010: golden = tr.a & tr.b;
                3'b011: golden = tr.a | tr.b;
                3'b100: golden = tr.a ^ tr.b;
                3'b101: golden = ~tr.a;
                3'b110: golden = tr.a << 1;
                3'b111: golden = tr.a >> 1;
                default: golden = 0;
            endcase
            gold_zero = (golden == 0);

            // Compare
            if (tr.exp_result === golden && tr.exp_zero === gold_zero) begin
                $display("PASS: a=%0d b=%0d opcode=%0d result=%0d",
                          tr.a, tr.b, tr.opcode, tr.exp_result);
                $fdisplay(fd, "PASS: a=%0d b=%0d opcode=%0d result=%0d",
                          tr.a, tr.b, tr.opcode, tr.exp_result);
            end else begin
                $display("FAIL: a=%0d b=%0d opcode=%0d DUT=%0d Expected=%0d",
                          tr.a, tr.b, tr.opcode, tr.exp_result, golden);
                $fdisplay(fd, "FAIL: a=%0d b=%0d opcode=%0d DUT=%0d Expected=%0d",
                          tr.a, tr.b, tr.opcode, tr.exp_result, golden);
            end
        end
    endtask
endclass


// -----------------------------
// Interface
// -----------------------------
interface alu_if #(parameter WIDTH=8);
    logic [WIDTH-1:0] a, b;
    logic [2:0] opcode;
    logic [WIDTH-1:0] result;
    logic zero;
endinterface


// -----------------------------
// Testbench Top
// -----------------------------
module alu_tb_sv;

    parameter WIDTH = 8;

    alu_if #(WIDTH) intf();
    alu #(WIDTH) dut (
        .a(intf.a),
        .b(intf.b),
        .opcode(intf.opcode),
        .result(intf.result),
        .zero(intf.zero)
    );

    mailbox gen2drv = new();
    mailbox mon2scb = new();

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    initial begin
        gen = new(gen2drv, 20);  // 20 random tests
        drv = new(gen2drv, intf);
        mon = new(intf, mon2scb);
        scb = new(mon2scb);

        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_any
        #100 $finish;
    end

endmodule

