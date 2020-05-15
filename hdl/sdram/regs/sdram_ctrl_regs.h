/*******************************************************************************
*                          AUTOGENERATED BY REGBLOCK                           *
*                            Do not edit manually.                             *
*          Edit the source file (or regblock utility) and regenerate.          *
*******************************************************************************/

#ifndef _SDRAM_REGS_H_
#define _SDRAM_REGS_H_

// Block name           : sdram
// Bus type             : apb
// Bus data width       : 32
// Bus address width    : 16

#define SDRAM_CSR_OFFS 0
#define SDRAM_TIME_OFFS 4
#define SDRAM_REFRESH_OFFS 8
#define SDRAM_ROW_COOLDOWN_OFFS 12
#define SDRAM_CMD_DIRECT_OFFS 16

/*******************************************************************************
*                                     CSR                                      *
*******************************************************************************/

// Control and status register

// Field: CSR_EN  Access: RW
// Enable bus access to SDRAM, and start issuing refresh commands. Should not be
// asserted until after the SDRAM initialisation sequence has been issued (e.g.
// a PrechargeAll, some AutoRefreshes, and a ModeRegisterSet).
#define SDRAM_CSR_EN_LSB  0
#define SDRAM_CSR_EN_BITS 1
#define SDRAM_CSR_EN_MASK 0x1
// Field: CSR_PU  Access: RW
// Power up (start driving clock and assert clock enable). Must be asserted
// before using CMD_DIRECT for start-of-day initialisation.
#define SDRAM_CSR_PU_LSB  1
#define SDRAM_CSR_PU_BITS 1
#define SDRAM_CSR_PU_MASK 0x2

/*******************************************************************************
*                                     TIME                                     *
*******************************************************************************/

// Configure SDRAM timing parameters. All times given in clock cycles. Unless
// otherwise specified, the minimum timing is 1 cycle, and this is encoded by a
// value of *0* in the relevant register field. Your SDRAM datasheet should
// provide these timings.

// Field: TIME_RC  Access: RW
// tRC: Row cycle time, row activate to row activate (same bank). tRFC, refresh
// cycle time, is assumed to be equal to this value. If these values are
// different in your datasheet, take the larger one.
#define SDRAM_TIME_RC_LSB  0
#define SDRAM_TIME_RC_BITS 3
#define SDRAM_TIME_RC_MASK 0x7
// Field: TIME_RCD  Access: RW
// tRCD: RAS to CAS delay (same bank).
#define SDRAM_TIME_RCD_LSB  4
#define SDRAM_TIME_RCD_BITS 3
#define SDRAM_TIME_RCD_MASK 0x70
// Field: TIME_RP  Access: RW
// tRP: Precharge to refresh/row activate command (same bank).
#define SDRAM_TIME_RP_LSB  8
#define SDRAM_TIME_RP_BITS 3
#define SDRAM_TIME_RP_MASK 0x700
// Field: TIME_RRD  Access: RW
// tRRD: Row activate to row activate delay (different banks).
#define SDRAM_TIME_RRD_LSB  12
#define SDRAM_TIME_RRD_BITS 3
#define SDRAM_TIME_RRD_MASK 0x7000
// Field: TIME_RAS  Access: RW
// tRAS: Row activate to precharge time (same bank).
#define SDRAM_TIME_RAS_LSB  16
#define SDRAM_TIME_RAS_BITS 3
#define SDRAM_TIME_RAS_MASK 0x70000
// Field: TIME_CAS  Access: RW
// CAS latency. Should match the value programmed into SDRAM mode register.
#define SDRAM_TIME_CAS_LSB  20
#define SDRAM_TIME_CAS_BITS 2
#define SDRAM_TIME_CAS_MASK 0x300000

/*******************************************************************************
*                                   REFRESH                                    *
*******************************************************************************/

// tREFI: Average refresh interval, in SDRAM clock cycles.

// Field: REFRESH  Access: RW
#define SDRAM_REFRESH_LSB  0
#define SDRAM_REFRESH_BITS 12
#define SDRAM_REFRESH_MASK 0xfff

/*******************************************************************************
*                                 ROW_COOLDOWN                                 *
*******************************************************************************/

// How many cycles to leave an unaccessed row open before closing. May only be
// changed when CSR_EN is low.

// Field: ROW_COOLDOWN  Access: RW
#define SDRAM_ROW_COOLDOWN_LSB  0
#define SDRAM_ROW_COOLDOWN_BITS 8
#define SDRAM_ROW_COOLDOWN_MASK 0xff

/*******************************************************************************
*                                  CMD_DIRECT                                  *
*******************************************************************************/

// Write to assert a command directly onto SDRAM e.g. Load Mode Register. Only
// to be used when bus is idle and CSR_EN is low (e.g. for start-of-day
// initialisation)

// Field: CMD_DIRECT_WE_N  Access: WF
#define SDRAM_CMD_DIRECT_WE_N_LSB  0
#define SDRAM_CMD_DIRECT_WE_N_BITS 1
#define SDRAM_CMD_DIRECT_WE_N_MASK 0x1
// Field: CMD_DIRECT_CAS_N  Access: WF
#define SDRAM_CMD_DIRECT_CAS_N_LSB  1
#define SDRAM_CMD_DIRECT_CAS_N_BITS 1
#define SDRAM_CMD_DIRECT_CAS_N_MASK 0x2
// Field: CMD_DIRECT_RAS_N  Access: WF
#define SDRAM_CMD_DIRECT_RAS_N_LSB  2
#define SDRAM_CMD_DIRECT_RAS_N_BITS 1
#define SDRAM_CMD_DIRECT_RAS_N_MASK 0x4
// Field: CMD_DIRECT_ADDR  Access: WF
#define SDRAM_CMD_DIRECT_ADDR_LSB  3
#define SDRAM_CMD_DIRECT_ADDR_BITS 13
#define SDRAM_CMD_DIRECT_ADDR_MASK 0xfff8
// Field: CMD_DIRECT_BA  Access: WF
#define SDRAM_CMD_DIRECT_BA_LSB  28
#define SDRAM_CMD_DIRECT_BA_BITS 2
#define SDRAM_CMD_DIRECT_BA_MASK 0x30000000

#endif // _SDRAM_REGS_H_
