#ifndef _CONSOLE_H
#define _CONSOLE_H
#endif

#include <stdint.h>
#include <stdio.h>

#include "platform_defs.h"
#include "tbman.h"
#include "uart.h"

// Shim for printing from either UART or testbench manager, depending on what
// hardware platform the software is running from. Intermediate step towards
// just wrapping stdout/stdin -- trying to keep infrastructure minimal to
// maximise chances of getting some debug output when the system is fucked :)

static inline void console_init() {
	if (!tbman_running_in_sim()) {
		uart_init();
		uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	}
}

static inline void console_puts(const char *s) {
	if (tbman_running_in_sim()) {
		tbman_puts(s);
	}
	else {
		uart_puts(s);
	}
}

static inline char console_getc() {
	if (tbman_running_in_sim()) {
		tbman_exit(0xbad10);
		__builtin_unreachable();
	}
	else {
		return (char)uart_get();
	}
}

static inline void console_putint(uint32_t x) {
	if (tbman_running_in_sim()) {
		tbman_putint(x);
	}
	else {
		uart_putint(x);
	}
}

static inline void console_printf(const char *fmt, ...) {
	char buf[PRINTF_BUF_SIZE];
	va_list args;
	va_start(args, fmt);
	vsnprintf(buf, PRINTF_BUF_SIZE, fmt, args);
	if (tbman_running_in_sim()) {
		tbman_puts(buf);
	}
	else {
		uart_puts(buf);
	}
	va_end(args);
}
