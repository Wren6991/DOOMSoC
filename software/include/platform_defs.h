#ifndef _PLATFORM_DEFS_H
#define _PLATFORM_DEFS_H

#include "addressmap.h"

#ifndef CLK_SYS_MHZ
#define CLK_SYS_MHZ 80
#endif

#ifndef UART_BAUD
#define UART_BAUD (3 * 1000 * 1000)
#endif

#ifndef PRINTF_BUF_SIZE
#define PRINTF_BUF_SIZE 128
#endif

#define VECTOR_TABLE_N_ENTRIES 48
#define VECTOR_TABLE_SIZE (4 * VECTOR_TABLE_N_ENTRIES)

#define CACHE_SIZE_WORDS 1024
#define CACHE_LINE_SIZE_WORDS 4

#endif
