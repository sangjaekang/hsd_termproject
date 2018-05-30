`timescale 1ns / 1ps

module convert_bit(
input wire [31:0] in,
output wire [31:0] out
);
/* DIFF
    l_to_b : little endian to big endian
    gdout_32 : float16 to float 32
    From zynq.cpp
    static inline float f16_to_f32(const uint32_t *input)
    {
        // Example :
           => input에 다음과 같이 정보가 담겨있다고 가정하자
        // 1 word(4bytes)  :  |  <3> | <2>  |  <1> |  <0> |
        // input           :  | [3f] | [2c] | [00] | [00] |
        char *iptc = (char*)input + 2; // iptc : input의 2번째 바이트를 가르키는 포인터
        uint32_t half_precision = 0; // half :  | [00] | [00] | [00] | [00] |
        memcpy(&half_precision, iptc + 1, 1); // input의 3번째 바이트를 half_precision의 0번째 바이트로 이동
        memcpy((void*)&half_precision) + 1, iptc, 1); // input의 2번째 바이트를 half_precision의 1번째 바이트로 이동
        // 그후적절히 변환
        uint32_t opt = ((half_precision & 0x8000) << 16)
                       | ((((half_precision & 0x7c00) >> 10) + 112) << 23)
                       | ((half_precision & 0x3FF) << 13);
*/

    wire [31:0] b_to_1;
    assign b_to_1[31:24] = 0;           // half_precision 3th bytes <- 0
    assign b_to_1[23:16] = 0;           // half_precision 2th bytes <- 0
    assign b_to_1[15:8]  = in[23:16];   // half_precision 1th bytes  <- input 2th bytes
    assign b_to_1[7:0]   = in[31:24];   // half_precision 0th bytes <- input 3th bytes

    wire [31:0] step_1;
    wire [31:0] step_2;
    wire [31:0] step_3;

    assign step_1 = ((b_to_1 & 'h8000) << 16);
    assign step_2 = ((((b_to_1 & 'h7c00) >> 10) + 112) << 23);
    assign step_3 = ((b_to_1 & 'h3FF) << 13);

    assign out= step_1 | step_2 | step_3;

endmodule

module pe_con#(
       parameter VECTOR_SIZE = 64, // Size of Vector
       parameter L_RAM_SIZE = 6    // Size of RAM
    )
    (
        input start,
        output done,
        input aclk,
        input aresetn,
        output [31:0] BRAM_ADDR,
        output [31:0] BRAM_WRDATA,
        output [3:0] BRAM_WE,
        output BRAM_CLK,
        input [31:0] BRAM_RDDATA
);
    // PE
    wire [31:0] ain;
    wire [31:0] din;
    wire [L_RAM_SIZE-1:0] addr;

    wire we_local [0:VECTOR_SIZE-1];
    wire we_global;
    wire valid;

    wire dvalid [0:VECTOR_SIZE-1];

    wire [31:0] dout [0:VECTOR_SIZE-1];
    wire [L_RAM_SIZE:0] rdaddr;
    reg [31:0] result [0:VECTOR_SIZE-1];

    wire [31:0] rddata;
    reg [31:0] wrdata;

    clk_wiz_0 u_clk (.clk_out1(BRAM_CLK), .clk_in1(aclk));
    // global block ram
    reg [31:0] gdout;
    (* ram_style = "block" *) reg [31:0] globalmem [0:VECTOR_SIZE-1];
    always @(posedge aclk)
        if (we_global)
            globalmem[addr] <= rddata;
        else
            gdout <= globalmem[addr];

//FSM
    // transition triggering flags
    wire load_done;
    wire calc_done;
    wire done_done;

    // state register
    reg [3:0] state, state_d;
    localparam S_IDLE = 4'd0;
    localparam S_LOAD = 4'd1;
    localparam S_CALC = 4'd2;
    localparam S_DONE = 4'd3;

//part 1: state transition
    always @(posedge aclk)
        if (!aresetn)
            state <= S_IDLE;
        else
            case (state)
                S_IDLE:
                    state <= (start)? S_LOAD : S_IDLE;
                S_LOAD:
                    state <= (load_done)? S_CALC : S_LOAD;
                S_CALC:
                    state <= (calc_done)? S_DONE : S_CALC;
                S_DONE:
                    state <= (done_done)? S_IDLE : S_DONE;
                default:
                    state <= S_IDLE;
            endcase

    always @(posedge aclk)
        if (!aresetn)
            state_d <= S_IDLE;
        else
            state_d <= state;

//part 2: determine state
    // S_LOAD
    reg load_flag;
    wire load_flag_reset = !aresetn || load_done;
    wire load_flag_en = (state_d == S_IDLE) && (state == S_LOAD);
    localparam ROWCNTLOAD = VECTOR_SIZE + 1;
    always @(posedge aclk)
        if (load_flag_reset)
            load_flag <= 'd0;
        else
            if (load_flag_en)
                load_flag <= 'd1;
            else
                load_flag <= load_flag;

    // S_CALC
    reg calc_flag;
    wire calc_flag_reset = !aresetn || calc_done;
    wire calc_flag_en = (state_d == S_LOAD) && (state == S_CALC);
    localparam ROWCNTCALC = (VECTOR_SIZE) - 1;
    always @(posedge aclk)
        if (calc_flag_reset)
            calc_flag <= 'd0;
        else
            if (calc_flag_en)
                calc_flag <= 'd1;
            else
                calc_flag <= calc_flag;

    // S_DONE
    reg done_flag;
    wire done_flag_reset = !aresetn || done_done;
    wire done_flag_en = (state_d == S_CALC) && (state == S_DONE);

    localparam ROWCNTDONE = 5 + VECTOR_SIZE; // vector_size 시간 동안 writing 동작을 함
    always @(posedge aclk)
        if (done_flag_reset)
            done_flag <= 'd0;
        else
            if (done_flag_en)
                done_flag <= 'd1;
            else
                done_flag <= done_flag;

    /*
    두 가지의 카운터로 움직임을 잡아줌
        1. row counter : 몇 번째 행인지 알려주는 카운터
        2. index counter : 몇 번째 원소인지 알려주는 카운터
    */

    // counter for row
    // : 몇번째 행임을 가르키는 카운터
    reg [31:0] row;
    wire wr_en;
    wire [31:0] ld_val = (load_flag_en)? ROWCNTLOAD :
                         (calc_flag_en)? ROWCNTCALC :
                         (done_flag_en)? ROWCNTDONE : 'd0;
    wire row_ld = load_flag_en || calc_flag_en || done_flag_en;
    wire row_en = dvalid[0] || done_flag || row_done;
    wire row_reset = !aresetn || load_done || calc_done || done_done;
    always @(posedge aclk)
        if (row_reset)
            row <= 'd0;
        else
            if (row_ld)
                row <= ld_val;
            else if (row_en)
                row <= row - 1;
    wire [31:0] cntdone_row;
    assign cntdone_row = (row - 5); // cntdone일 경우, 대기 시간(5) 만큼 빼주어야 sync가 맞음

    // counter for index
    // 특정 행의 몇 번째 원소임을 가르키는 카운터
    reg [31:0] index;
    wire index_ld = load_flag_en || row_done;
    wire index_en = load_flag;
    wire index_reset = !aresetn;
    localparam INDEXCNTLOAD = (2*VECTOR_SIZE) - 1; // INDEX COUNTER
    always @(posedge aclk)
        if (index_reset)
            index <= 'd0;
        else
            if (index_ld)
                index <= INDEXCNTLOAD;
            else if (index_en)
                index <= index - 1;
    assign row_done = (load_flag) && (index == 'd0); // 해당 row가 종료되었을 때

    //part3: update output and internal register
    //S_LOAD: we
    genvar i;
    generate
       for(i = 0; i <VECTOR_SIZE; i = i + 1) begin:LOCAL_WE_SET
           assign we_local[i] = (load_flag && ((row -1) == i)) ? 'd1 : 'd0;
       end
    endgenerate
    assign we_global = (load_flag && (row == (VECTOR_SIZE + 1))) ? 'd1 : 'd0;

    //S_CALC: wrdata
    always @(posedge aclk)
        if (!aresetn)
                wrdata <= 'd0;
        else
            if (wr_en)
                    wrdata <= result[cntdone_row-1];
            else
                    wrdata <= wrdata;
    assign wr_en = (state==S_DONE)&& row >= 5;

    //S_CALC: valid
    reg valid_pre, valid_reg;
    always @(posedge aclk)
        if (!aresetn)
            valid_pre <= 'd0;
        else
            if (row_ld || row_en)
                valid_pre <= 'd1;
            else
                valid_pre <= 'd0;

    always @(posedge aclk)
        if (!aresetn)
            valid_reg <= 'd0;
        else if (calc_flag)
            valid_reg <= valid_pre;

    assign valid = (calc_flag) && valid_reg;

    //S_CALC: ain
    assign ain = (calc_flag)? gdout : 'd0;

    //S_LOAD&&CALC
    assign addr = (load_flag)? index[L_RAM_SIZE:1]:
                  (calc_flag || done_flag) ? row[L_RAM_SIZE-1:0]: 'd0;

    //S_LOAD
    assign din = (load_flag)? rddata : 'd0;
    assign rdaddr = (state == S_LOAD)? index[L_RAM_SIZE+1:1] : 'd0;

    //done signals
    assign load_done = (load_flag) && (row == 'd0);
    assign calc_done = (calc_flag) && (row == 'd0) && dvalid[0]; // 마지막 dvalid가 되었을 때
    assign done_done = (done_flag) && (row == 'd0);
    assign done = (state == S_DONE) && done_done;

    generate
        for (i = 0; i <VECTOR_SIZE; i = i + 1) begin:SAVE_RESULT
            always @(posedge calc_done)
                result[i] <= dout[i];
        end
    endgenerate

    // converting 16bit big-endian to 32bit little-endian
    wire [31:0] rddata_32;
    convert_bit CB(
      .in(BRAM_RDDATA),
    .out( rddata_32)
    );
    assign rddata = rddata_32;
    assign BRAM_WRDATA = wrdata;

    // BRAM에서 data를 load할 때의 주소값
    wire[31:0] load_addr;
    assign load_addr = (we_global) ?
                            { {29-L_RAM_SIZE{1'b0}}, (rdaddr+VECTOR_SIZE*VECTOR_SIZE), 2'b00} :
                            { {29-L_RAM_SIZE{1'b0}}, (rdaddr + VECTOR_SIZE*(row-1)) , 2'b00};
    // BRAM에 data를 저장할 때의 주소값
    wire[31:0] write_addr;
    assign write_addr = {{29-L_RAM_SIZE{1'b0}}, cntdone_row, 2'b00};
    assign BRAM_ADDR = (done_flag_en) ? 'b0 :
                              (wr_en) ? write_addr : load_addr;
    assign BRAM_WE = (done_flag_en || wr_en)? 4'hF: 0;

    generate
        for(i = 0; i < VECTOR_SIZE; i = i + 1) begin:PE_SET
        my_pe #(
            .L_RAM_SIZE(L_RAM_SIZE)
        ) u_pe (
            .aclk(aclk),
            .aresetn(aresetn && (state != S_DONE)),
            .ain(ain),
            .din(din),
            .addr(addr),
            .we(we_local[i]),
            .valid(valid),
            .dvalid(dvalid[i]),
            .dout(dout[i])
        );
       end
    endgenerate
endmodule
