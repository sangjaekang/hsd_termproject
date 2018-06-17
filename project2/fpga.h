#ifndef FPGA_H
#define FPGA_H

#include "zynq.h"

class fpga_tb : public zynq_tb
{
public:
	fpga_tb() = delete;
	fpga_tb(const fpga_tb &) = delete;
	fpga_tb(const fpga_tb &&) = delete;

	fpga_tb &operator=(const fpga_tb &) = delete;
	fpga_tb &operator=(const fpga_tb &&) = delete;

	fpga_tb(size_t size_shifter) : zynq_tb(size_shifter){}
	~fpga_tb(){}

	void fpga_allocate_resources();
	void fpga_load_execute_and_copy(const uint16_t *ipt_matrix_fix16, const uint16_t *ipt_vector_fix16, uint32_t *your_vector_fix32);
	void fpga_cleanup();

private:
	//Add your variables/functions here.
	int foo;
	volatile uint16_t *fpga_bram;
	volatile unsigned int *fpga_ip;
};

#endif
