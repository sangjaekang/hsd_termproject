#include "fpga.h"

#include <cstdio>
#include <cstring>

#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <sys/mman.h>

#define BRAM_BASE 0x40000000

#define MATRIX_ADDR BRAM_BASE
#define IPT_VECTOR_ADDR (MATRIX_ADDR + (MATRIX_SIZE * MATRIX_SIZE * sizeof(uint16_t)))
#define OPT_VECTOR_ADDR (IPT_VECTOR_ADDR + MATRIX_SIZE * sizeof(uint16_t))

#define INSTRUCTION_ADDR 0x43C00000
#define MAGIC_CODE 0x5555

//you can add variables in here too (It is recommanded to modify fpga_tb class's private field).

void fpga_tb::fpga_allocate_resources()
{
	//allocate resource.
    foo = open("/dev/mem", O_RDWR | O_NONBLOCK);
    fpga_bram = (volatile uint16_t *)mmap(NULL, (matrix_size*(matrix_size+1))*sizeof(uint16_t), PROT_WRITE | PROT_READ, MAP_SHARED, foo, BRAM_BASE);
    fpga_ip = (volatile unsigned int*)mmap(NULL, sizeof(float), PROT_WRITE, MAP_SHARED, foo, INSTRUCTION_ADDR);
}

void fpga_tb::fpga_load_execute_and_copy(const uint16_t *ipt_matrix_fix16, const uint16_t *ipt_vector_fix16, uint32_t *your_vector_fix32)
{
	//Copy data to BRAM(or you may use DMA).
    for (int i = 0; i < matrix_size*matrix_size; i++) {
        *(fpga_bram + i) = *(ipt_matrix_fix16 + i);
    }
    for (int i = 0; i < matrix_size; i++){
        *(fpga_bram + matrix_size*matrix_size + i) = *(ipt_vector_fix16 + i);
    }
	//Execute your magic code.
    *fpga_ip = 0x5555;
    while(*fpga_ip == 0x5555);

    //and copy BRAM's data to DRAM space.
    memcpy((void *)your_vector_fix32, (const void *)fpga_bram, matrix_size*sizeof(uint32_t));

}

void fpga_tb::fpga_cleanup()
{
	//Cleanup allocated resources.
    munmap(fpga_ip, sizeof(float));
    munmap(fpga_bram, sizeof(float));
    close(foo);
}
