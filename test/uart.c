#include "uart.h"
#include <avr/io.h>
#include <avr/pgmspace.h>

void uart_real_init(unsigned int speed_setting)
{
  // set baudrate (UBRR Register)
  UBRRH = (unsigned char) (speed_setting >> 8);       
  UBRRL = (unsigned char) speed_setting;
  
  // Enable reiceive & transmitt
  UCSRB = (1 << RXEN) | (1 << TXEN); //| (1 << RXCIE);

  // Use 8 databits + 1 stop bits
  // URSEL     =   1 -> UCSRC should be written to
  // UMSEL     =   0 -> Asynchronouse Mode
  // UPM[1:0]  =  00 -> no parity
  // USBS      =   0 -> 1 stop bit
  // UCSZ[2:0] = 011 -> 8 bit
  // UCPOL     =   0 -> transmit on rising edge / receive on falling edge
  
  UCSRC = (1 << URSEL) | (0x3 << UCSZ0);

}

void uart_transmit(unsigned char data_byte)
{
  // wait until last transmit completed (blocking)
  while(!(UCSRA & (1 << UDRE)));
  
  UDR = data_byte;
}

unsigned char uart_peek(void)
{
  if((UCSRA & (1 << RXC)))
    return 1;
  else
    return 0;
}

void uart_wait_tx(void)
{
  while(!(UCSRA & (1 << TXC)));
}

unsigned char uart_receive(void)
{
  // wait until receive is complete (blocking)
  while(!(UCSRA & (1 << RXC)));
  
  return UDR;
}

void uart_putchar(char ch)
{
  while(!(UCSRA & (1 << UDRE)));
  
  UDR = ch;
}

char uart_getchar(void)
{
  // wait until receive is complete (blocking)
  while(!(UCSRA & (1 << RXC)));
  
  return UDR;
}

#define write_hex_digit(digit)  if(digit > 9) \
                  uart_transmit(digit + ('a' - 0xA)); \
                else \
                  uart_transmit(digit + '0')

void uart_write_bhex(const unsigned char ch)
{
  const unsigned char hn = ((ch >> 4) & 0x0f);
  const unsigned char ln = (ch & 0x0f);
  write_hex_digit(hn);
  write_hex_digit(ln);
  uart_transmit(' ');
}

void uart_write_shex(const unsigned short val)
{
  const unsigned char val1 = (unsigned char)((val & 0xf000) >> 12);
  const unsigned char val2 = (unsigned char)((val & 0x0f00) >> 8);
  const unsigned char val3 = (unsigned char)((val & 0x00f0) >> 4);
  const unsigned char val4 = (unsigned char)(val & 0x000f);
  
  write_hex_digit(val1);
  write_hex_digit(val2);
  write_hex_digit(val3);
  write_hex_digit(val4);
  uart_transmit(' ');
}

void uart_write_str(const char* buffer)
{
  char ch;
  while((ch = *buffer++) != 0)
    uart_putchar(ch); 
}


void uart_write_pstr(const char* buffer)
{
  char ch = pgm_read_byte(buffer);
  while(ch != 0)
  {
    uart_putchar(ch);
    ++buffer;
    ch = pgm_read_byte(buffer);
  }
}

