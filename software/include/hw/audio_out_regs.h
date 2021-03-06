/*******************************************************************************
*                          AUTOGENERATED BY REGBLOCK                           *
*                            Do not edit manually.                             *
*          Edit the source file (or regblock utility) and regenerate.          *
*******************************************************************************/

#ifndef _AUDIO_OUT_REGS_H_
#define _AUDIO_OUT_REGS_H_

// Block name           : audio_out
// Bus type             : apb
// Bus data width       : 32
// Bus address width    : 16

#define AUDIO_OUT_CSR_OFFS 0
#define AUDIO_OUT_DIV_OFFS 4
#define AUDIO_OUT_FIFO_OFFS 8

/*******************************************************************************
*                                     CSR                                      *
*******************************************************************************/

// Control and status register

// Field: CSR_EN  Access: RW
// Enable audio output
#define AUDIO_OUT_CSR_EN_LSB  0
#define AUDIO_OUT_CSR_EN_BITS 1
#define AUDIO_OUT_CSR_EN_MASK 0x1
// Field: CSR_FMT_SIGNED  Access: RW
// If 1, samples are interpreted as signed integers.
#define AUDIO_OUT_CSR_FMT_SIGNED_LSB  1
#define AUDIO_OUT_CSR_FMT_SIGNED_BITS 1
#define AUDIO_OUT_CSR_FMT_SIGNED_MASK 0x2
// Field: CSR_FMT_16  Access: RW
// If 1, samples are 16-bit. If 0, 8-bit. Samples are always packed into a
// 32-bit FIFO word.
#define AUDIO_OUT_CSR_FMT_16_LSB  2
#define AUDIO_OUT_CSR_FMT_16_BITS 1
#define AUDIO_OUT_CSR_FMT_16_MASK 0x4
// Field: CSR_FMT_MONO  Access: RW
// If 1, the same sample is sent to both output channels. If 0, a different
// output sample to each channel. Samples are always consumed least-significant-
// first from the FIFO word, and the left channel is less significant than the
// right channel.
#define AUDIO_OUT_CSR_FMT_MONO_LSB  3
#define AUDIO_OUT_CSR_FMT_MONO_BITS 1
#define AUDIO_OUT_CSR_FMT_MONO_MASK 0x8
// Field: CSR_IE  Access: RW
// Interrupt enable for half-full interrupt
#define AUDIO_OUT_CSR_IE_LSB  8
#define AUDIO_OUT_CSR_IE_BITS 1
#define AUDIO_OUT_CSR_IE_MASK 0x100
// Field: CSR_EMPTY  Access: ROV
// Sample FIFO is empty
#define AUDIO_OUT_CSR_EMPTY_LSB  29
#define AUDIO_OUT_CSR_EMPTY_BITS 1
#define AUDIO_OUT_CSR_EMPTY_MASK 0x20000000
// Field: CSR_FULL  Access: ROV
// Sample FIFO is full
#define AUDIO_OUT_CSR_FULL_LSB  30
#define AUDIO_OUT_CSR_FULL_BITS 1
#define AUDIO_OUT_CSR_FULL_MASK 0x40000000
// Field: CSR_HALF_FULL  Access: ROV
// FIFO is no more than half full. This is the sign bit, so is fast to check.
#define AUDIO_OUT_CSR_HALF_FULL_LSB  31
#define AUDIO_OUT_CSR_HALF_FULL_BITS 1
#define AUDIO_OUT_CSR_HALF_FULL_MASK 0x80000000

/*******************************************************************************
*                                     DIV                                      *
*******************************************************************************/

// Divider for oversampling clock. The fractional division is just first-order,
// so use integer multiples if you can.

// Field: DIV_FRAC  Access: RW
#define AUDIO_OUT_DIV_FRAC_LSB  0
#define AUDIO_OUT_DIV_FRAC_BITS 8
#define AUDIO_OUT_DIV_FRAC_MASK 0xff
// Field: DIV_INT  Access: RW
#define AUDIO_OUT_DIV_INT_LSB  8
#define AUDIO_OUT_DIV_INT_BITS 10
#define AUDIO_OUT_DIV_INT_MASK 0x3ff00

/*******************************************************************************
*                                     FIFO                                     *
*******************************************************************************/

// Write access for sample FIFO

// Field: FIFO  Access: WF
#define AUDIO_OUT_FIFO_LSB  0
#define AUDIO_OUT_FIFO_BITS 32
#define AUDIO_OUT_FIFO_MASK 0xffffffff

#endif // _AUDIO_OUT_REGS_H_
