`timescale 1ns / 1ps

module mac_pe #(
        parameter L_RAM_SIZE = 6
    )
    (
        // clk/reset
        input aclk,
        input aresetn,
        // port A
        input [15:0] ain,
        // peram -> port B
        input [31:0] din,
        input [L_RAM_SIZE-1:0] addr,
        input we,
        // integrated valid signal
        input valid,
        // computation result
        output dvalid,
        output [31:0] dout
    );

    // peram: PE's local RAM -> Port B
    reg [15:0] bin;
    (* ram_style = "block" *) reg [15:0] peram [0:2**L_RAM_SIZE - 1];

    always @(posedge aclk)
        if (we) begin
            peram[2*addr] <= din[31:16];
            peram[2*addr+1] <= din[15:0];
        end else
            bin <= peram[addr];

    reg [31:0] dout_fb;
    always @(posedge aclk)
        if (!aresetn)
            dout_fb <= 'd0;
        else
            if (dvalid)
                dout_fb <= dout;
            else
                dout_fb <= dout_fb;

    // convert from fixed to float
    wire avalid;
    wire [31:0] aout;
    fixed_to_float ff_a (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_a_tvalid(valid),
    .s_axis_a_tdata(ain),
    .m_axis_result_tvalid(avalid),
    .m_axis_result_tdata(aout)
    );

    // convert from fixed to float
    wire [31:0] bout;
    wire bvalid;
    fixed_to_float ff_b (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axis_a_tvalid(valid),
    .s_axis_a_tdata(bin),
    .m_axis_result_tvalid(bvalid),
    .m_axis_result_tdata(bout)
    );
    wire cvalid = avalid;

    floating_point_0 u_float_dsp (
        .aclk             (aclk),
        .aresetn          (aresetn),
        .s_axis_a_tvalid  (avalid),
        .s_axis_a_tdata   (aout),
        .s_axis_b_tvalid  (bvalid),
        .s_axis_b_tdata   (bout),
        .s_axis_c_tvalid  (cvalid),
        .s_axis_c_tdata   (dout_fb),
        .m_axis_result_tvalid (dvalid),
        .m_axis_result_tdata  (dout)
   );

   endmodule
