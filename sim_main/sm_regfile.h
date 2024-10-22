/*
 * sm_regfile.h
 *
 *  Created on: Dec 9, 2013
 *      Author: isaac
 */

#ifndef SM_REGFILE_H_
#define SM_REGFILE_H_
#include "my_def.h"
#include <stdint.h>
#ifndef OOO
    #ifdef REMAP
        #include "VMIPS_TABLE_obj.h"
        #include "VMIPS_PHYS_REG.h"
        #include "VMIPS_ID.h"
    #else
        #include "VMIPS_RegFile.h"
    #endif
    #include "VMIPS_EXE.h"
#else
#include "VMIPS_PhysRegFile.h"
#include "VMIPS_RetireCommit.h"
#endif



#ifndef OOO
    #ifdef REMAP
        void init_register_access(VMIPS_ID *id, VMIPS_EXE *exe);
    #else
        void init_register_access(VMIPS_RegFile *rf, VMIPS_EXE *exe);
    #endif

#else
void init_register_access(VMIPS_PhysRegFile *prf, VMIPS_RetireCommit *rc);
#endif

uint32_t read_register(uint32_t regno);
uint32_t register_arch_to_phys(uint32_t regno);
void write_register(uint32_t regno, uint32_t value);



#endif /* SM_REGFILE_H_ */
