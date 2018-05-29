### TEST-BENCH

1. **tb_convert.v**

   * 목적

     > 16 bit big endian을 32 bit little endian으로 변경

   * Input 파일 : tb_convert_16be.txt

   * 정답지 : tb_convert_16be_answer.csv

   * 결과 : 정답

2. ​**tb_basic_pe_con.v**
    * 목적
      > 64 vector size의 32bit big endian이 정상적으로 동작하는지 확인

    * Input 파일 :
        1. tb_basic_pe_ex0.txt
        2. tb_basic_pe_ex1.txt

    * 정답지 :
        1. tb_basic_pe_ex0_out.txt
        2. tb_basic_pe_ex1_out.txt

3. ​**tb_convert_pe_con.v**
    * 목적
      > 64 vector size의 16bit little endian을 받아서 정상적으로 동작하는지 확인

    * Input 파일 : tb_convert_pe_ex1.txt

    * 정답지 : tb_convert_pe_ex1_out.txt
