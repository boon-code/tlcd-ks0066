#include "tlcd.h"
#include "ks0066.h"

#define F_CPU F_OSC
#include <avr/io.h>
#include <util/delay.h>

#define DATA_MASK (0xf << TLCD_LSB_PIN)
#define INV_DATA_MASK ~DATA_MASK

#define output_4hexbits(ni) if(ni > 0x09) 										\
														{ write_byte(('a' - 0x09) + ni);} \
														else 															\
														{ write_byte('0' + ni);} 					\
														short_wait()


static void init_wait(void)
{
	_delay_ms(INIT_WAIT_MS);
}

static void long_wait(void)
{
	_delay_ms(LONG_WAIT_MS);
}

static void short_wait(void)
{
	_delay_us(SHORT_WAIT_US);
}

static void data_sig_wait(void)
{
	_delay_us(DATA_SIG_WAIT_US);
}

static void u_wait(void)
{
	_delay_us(1);
}

static void on_e(void)
{
	TLCD_FS_PORT |= _BV(TLCD_FS_EN);
	data_sig_wait();
}

static void off_e(void)
{
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_EN));
	data_sig_wait();
}

static void toggle_e(void)
{
	TLCD_FS_PORT |= _BV(TLCD_FS_EN);
	data_sig_wait();
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_EN));
	data_sig_wait();
}

static void output(unsigned char data)
{
	unsigned char val = (data << TLCD_LSB_PIN) & DATA_MASK;
	unsigned char old = TLCD_DATA_PORT & INV_DATA_MASK;
	u_wait();
	TLCD_DATA_PORT = old | val;
}

static void write_byte(unsigned char data)
{
	output(data >> 4);
	toggle_e();
	output(data);
	toggle_e();
}

static void write_hexb(unsigned char value)
{
	unsigned char ni = (value >> 4) & 0x0f;
	output_4hexbits(ni);
	
	ni = value & 0x0f;
	output_4hexbits(ni);
}

void tlcd_str(const char* text)
{
	char ch = 0;
	TLCD_FS_PORT |= _BV(TLCD_FS_RS);
	u_wait();
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_RW));
	u_wait();
	while(ch = *(text++))
	{
		write_byte(ch);
		short_wait();
	}
}

void tlcd_write_hexb(unsigned char data)
{
	TLCD_FS_PORT |= _BV(TLCD_FS_RS);
	u_wait();
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_RW));
	u_wait();
	
	write_byte('0');
	short_wait();
	write_byte('x');
	short_wait();
	
	write_hexb(data);
}

void tlcd_write_hexi(unsigned int data)
{
	unsigned char low = data & 0xff;
	unsigned char high = data & 0xff00;
	
	TLCD_FS_PORT |= _BV(TLCD_FS_RS);
	u_wait();
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_RW));
	u_wait();
	
	write_byte('0');
	short_wait();
	write_byte('x');
	short_wait();
	
	write_hexb(high);
	write_hexb(low);
}

void tlcd_set_ddram(unsigned char addr)
{
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_RW) | _BV(TLCD_FS_RS));
	u_wait();
	
	write_byte(SET_DDRAM_ADDR | (addr & DDRAM_ADDR_MASK));
	short_wait();
}

void clear_screen(void)
{
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_RS) | _BV(TLCD_FS_RW));
	u_wait();
	write_byte(CLEAR_DISPLAY);
	long_wait();
}

void return_home(void)
{
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_RS) | _BV(TLCD_FS_RW));
	u_wait();
	write_byte(RETURN_HOME);
	long_wait();
}

static unsigned char read_busy(void)
{
	unsigned char value = 0;
	unsigned char temp = 0;
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_RS));
	u_wait();
	TLCD_DATA_DDR &= ~DATA_MASK;
	u_wait();
	TLCD_DATA_PORT &= ~DATA_MASK;
	TLCD_FS_PORT |= _BV(TLCD_FS_RW);
	short_wait();
	on_e();
	temp = (TLCD_DATA_PIN >> TLCD_LSB_PIN) & 0xf;
	value = temp << 4;
	off_e();
	
	on_e();
	temp = (TLCD_DATA_PIN >> TLCD_LSB_PIN) & 0xf;
	off_e();
	
	value |= temp;
	
	TLCD_DATA_DDR |= DATA_MASK;
	
	return value;
}

static void real_init(void)
{
	init_wait();
	TLCD_DATA_DDR |= DATA_MASK;
	TLCD_FS_DDR |= (_BV(TLCD_FS_EN) | _BV(TLCD_FS_RS) | _BV(TLCD_FS_RW));
	TLCD_FS_PORT &= ~(_BV(TLCD_FS_EN) | _BV(TLCD_FS_RS) | _BV(TLCD_FS_RW));
	init_wait();
	
	output(FUNCTION_SET_BASIC | FS_TWO_LINE);
	toggle_e();
	long_wait();
	write_byte(FUNCTION_SET_BASIC | FS_TWO_LINE);
	long_wait();
	write_byte(FUNCTION_SET_BASIC | FS_TWO_LINE);
	long_wait();
	
	write_byte(DISPLAY_CONTROL_BASIC | DISPLAY_ON | CURSOR_BLINK);
	short_wait();
	
	write_byte(CLEAR_DISPLAY);
	long_wait();
	
	write_byte(ENTRY_MODE_BASIC |  ENTRY_MODE_ID);
	long_wait();
}

void tlcd_init(void)
{
	for(unsigned char i = 0; i < TLCD_REINIT_COUNT; ++i)
	{
		real_init();
	}
}

