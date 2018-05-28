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
