`timescale 1ns / 1ps

module tb_convert();
    parameter CLK_PERIOD = 10;
    reg [31:0] din;
    wire [31:0] dout;
    reg [5:0] rdaddr;
    integer i;

    // load data
    reg [31:0] din_mem [20-1:0];
    initial
        $readmemb("/home/ksj/lecture/hardware/term/test/tb_convert_16be.txt", din_mem);

    initial begin
        din <= 0;
        rdaddr <= 0;
        #(CLK_PERIOD);
        for (i=0; i<20; i=i+1) begin
            din <= din_mem[rdaddr];
            rdaddr <= rdaddr +1;
            #(CLK_PERIOD);
        end
    end

    convert_bit CB(
        .in(din),
        .out(dout)
        );

endmodule
