### 하시설 TERM-PROJECT

-----

#### 디렉토리 구성

1. **source**

    * bram.v

      : 이전 lab에서 제공된 bram.v

      ````verilog
      $readmemh(INIT_FILE, mem);
      ````

      헥사로 읽는 코드를 바이트로 읽도록만 수정

      ```verilog
      $readmemb(INIT_FILE, mem);
      ```

    * my_pe.v

      : lab에서 제공된 my_pe.v

    * pe_con.v

      : lab에서 제공된 pe_con.v

    * convert_bit.v

      : 16bit big-endian을 읽어서 32bit little-endian으로 바꾸는 코드

    * convert_pe_con.v

      : convert_bit.v를 pe_con.v에 연결시켜서 16bit big-endian을 읽어서 32bit little-endian으로 바꾸어 pe_con에서 연산하는 코드

    * matrix_pe_con.v

      : term-project 최종 결과, Matrix x Vector 연산하는 코드

2. **test**

    * **디렉토리**
      * scripts

        python 코드로 작성된 테스트 데이터셋 생성 코드

        jupyter notebook(*.ipyb)으로 작성되어 있음

      * input

        test에 사용되는 input file이 담긴 폴더

      * answer

        test에 사용되는 값이 옳은지 판단하는 기준 파일이 담긴 폴더

    * **파일**

      * tb_convert.v

        convt_bit.v가 정상적으로 작동하는지 확인하는 코드

