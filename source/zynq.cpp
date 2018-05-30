#include "zynq.h"

#include <cstring>
#include <sys/time.h>

#include <cstdio>	//for perror
#include <sys/mman.h>	//mmap

#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>

#define BRAM_BASE 0x40000000

#define MATRIX_ADDR BRAM_BASE
#define IPT_VECTOR_ADDR (MATRIX_ADDR + (MATRIX_SIZE * MATRIX_SIZE * sizeof(uint32_t)))
#define OPT_VECTOR_ADDR (IPT_VECTOR_ADDR + MATRIX_SIZE * sizeof(uint32_t))
#define SIZE 64

#define INSTRUCTION_ADDR 0x43C00000
#define MAGIC_CODE 0x5555

static inline float f16_to_f32(const uint32_t *input);

double fpga_calculate(uint32_t *ipt_matrix_f16, uint32_t *ipt_vector_f16, float *your_vector_f32)
{
	//Map BRAM to virtual memory space and copy data.
	// 1. Map BRAM to virtual memory space
	int foo = open("/dev/mem", O_RDWR | O_NONBLOCK);
	volatile uint32_t *fpga_bram = (volatile uint32_t *)mmap(NULL, (SIZE*(SIZE+1))*sizeof(float), PROT_WRITE | PROT_READ, MAP_SHARED, foo, BRAM_BASE);

	// 2. copy data
	for (int i = 0; i < SIZE*SIZE; i++) {
		*(fpga_bram + i) = *(ipt_matrix_f16 + i);
	}
	for (int i = 0; i < SIZE; i++){
		*(fpga_bram + SIZE*SIZE + i) = *(ipt_vector_f16 + i);
	}

    	// initialize
    	*your_vector_f32 = 0.0f;

    	struct timeval start, end;
    	gettimeofday(&start, NULL);

    	//Run IP and copy value to DRAM space
    	volatile unsigned int *fpga_ip = (volatile unsigned int*)mmap(NULL, sizeof(float), PROT_WRITE, MAP_SHARED, foo, INSTRUCTION_ADDR);

    	*fpga_ip = 0x5555;

    	// wait
    	while (*fpga_ip == 0x5555);
	
	memcpy((void *)your_vector_f32, (const void *)fpga_bram, SIZE*sizeof(float));
    	gettimeofday(&end, NULL);

    	//Cleanup allocated resources (optional).

    	return (double)(end.tv_sec - start.tv_sec) + ((double)(end.tv_usec - start.tv_usec)) / 1000000.0;
}

double arm_calculate(uint32_t *ipt_matrix_f16, uint32_t *ipt_vector_f16, float *arm_vector_f32)
{
	struct timeval start, end;
	gettimeofday(&start, NULL);

	memset(arm_vector_f32, 0, sizeof(float) << SIZE_SHIFTER);

	for(size_t i = -1 ; ++i < matrix_size * matrix_size ; arm_vector_f32[i >> SIZE_SHIFTER]
		+= f16_to_f32(ipt_matrix_f16 + i) * f16_to_f32(ipt_vector_f16 + (i & ((1 << SIZE_SHIFTER) - 1))));

	gettimeofday(&end, NULL);
	return (double)(end.tv_sec - start.tv_sec) + ((double)(end.tv_usec - start.tv_usec)) / 1000000.0;
}

static inline float f16_to_f32(const uint32_t *input)
{
	char *iptc = (char*)input + 2;

	uint32_t half_precision = 0;
	memcpy(&half_precision, iptc + 1, 1);
	memcpy(((void*)&half_precision) + 1, iptc, 1);

	uint32_t opt 	= ((half_precision & 0x8000) << 16)
			| ((((half_precision & 0x7C00) >> 10) + 112) << 23)
			| ((half_precision & 0x3FF) << 13);

	float casted_opt;
	memcpy(&casted_opt, &opt, sizeof(float));
	return casted_opt;
}
