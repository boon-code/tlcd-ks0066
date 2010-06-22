#define F_CPU F_OSC
#include <avr/io.h>
#include <util/delay.h>
#include "tlcd.h"

#include "uart.h"

#define sbi(port, bit) (port) |= (1 << (bit))
#define cbi(port, bit) (port) &= ~(1 << (bit))

int main(void)
{
	DDRD = _BV(PD6);
	tlcd_init();
	_delay_ms(1000);
	
	tlcd_str("init uart ");
	tlcd_write_hexi(9600);
	uart_init(9600);
	_delay_ms(1000);
	tlcd_set_ddram(0x40);
	sbi(PORTD, PD6);
	tlcd_str("done");
	_delay_ms(1000);
	clear_screen();
	
	while(1)
	{
		uart_write_str("Hallo");
		tlcd_str("Hallo");
		
		_delay_ms(1000);
		
		tlcd_str("hui");
		
		_delay_ms(1000);
		
		clear_screen();
	}
	
	return 0;
}

