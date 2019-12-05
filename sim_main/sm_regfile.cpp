/*
 * sm_regfile.cpp
 *
 *  Created on: Dec 9, 2013
 *      Author: isaac
 */

#include <verilated.h>		//verilator lib
#include "sm_regfile.h"
#include "my_def.h"

#ifndef OOO
//******************************************************************************
		#ifdef REMAP
				static VMIPS_PHYS_REG* _RegFile = NULL;
				static VMIPS_EXE* _EXE = NULL;
				static VMIPS_TABLE_obj* _FRAT = NULL;
				void init_register_access(VMIPS_ID *id, VMIPS_EXE *exe) {
						_RegFile = id->PHYS_REG;
						_EXE = exe;
						_FRAT = id->FRAT;
				}
				#define REG_FILE_VALID	(_RegFile && _EXE)
				#define REG_ACCESS(regno) _RegFile->arr[_FRAT->arr[regno]]
		#else
				static VMIPS_RegFile* _RegFile = NULL;
				static VMIPS_EXE* _EXE = NULL;
				void init_register_access(VMIPS_RegFile *rf, VMIPS_EXE *exe) {
					_RegFile = rf;
					_EXE = exe;
				}

				#define REG_FILE_VALID	(_RegFile && _EXE)
				#define REG_ACCESS(regno)	_RegFile->Reg[regno]
		#endif
//******************************************************************************
static inline uint32_t REG_READ(uint32_t regno) {
	if(regno < 32) {
		return REG_ACCESS(regno);
	}
	return (regno == 33)?_EXE->LO:_EXE->HI;
}
static inline void REG_WRITE(uint32_t regno, uint32_t value) {
	if(regno < 32) {
		REG_ACCESS(regno) = value;
	}
}
#else

//******************************************************************************
static VMIPS_PhysRegFile* _PhysRegFile = NULL;
static VMIPS_RetireCommit* _RC = NULL;

void init_register_access(VMIPS_PhysRegFile *prf, VMIPS_RetireCommit *rc){
	_PhysRegFile = prf;
	_RC = rc;
}

#define REG_FILE_VALID	(_PhysRegFile && _RC)
#define REG_ACCESS(regno)	_PhysRegFile->PReg[register_arch_to_phys(regno)]
#define REG_READ(regno)		REG_ACCESS(regno)
#define REG_WRITE(regno,value)	REG_ACCESS(regno)=(value)
#endif

uint32_t read_register(uint32_t regno) {
	if(!REG_FILE_VALID) {
		printf("BUG: FAULURE TO init_register_access()");
		return -1;
	}
	if(regno == 0) {
		return 0;
	}
	return REG_READ(regno);
}
void write_register(uint32_t regno, uint32_t value) {
	if(!REG_FILE_VALID) {
		printf("BUG: FAULURE TO init_register_access()");
	}
	REG_WRITE(regno, value);
}

uint32_t register_arch_to_phys(uint32_t regno) {
#ifndef OOO
	return regno;
#else
	if(!_RC) {
		printf("BUG: FAILURE to init_register_access()");
		return 0;
	}
	return _RC->RRAT__DOT__regPtrs[regno];
#endif
}
