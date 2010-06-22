#ifndef _UART_MODULE_H_
#define _UART_MODULE_H_

// atmega 16
#define GET_UBRR_FROM_BAUDRATE(BAUD) F_OSC/16/(BAUD)-1

void uart_real_init(unsigned int speed_setting);
#define uart_init(baud_rate) (uart_real_init(GET_UBRR_FROM_BAUDRATE(baud_rate)))

void uart_transmit(unsigned char data_byte);
unsigned char uart_receive(void);
unsigned char uart_peek(void);
void uart_wait_tx(void);

void uart_putchar(char ch);
char uart_getchar(void);

void uart_write_bhex(const unsigned char ch);
void uart_write_shex(const unsigned short val);
void uart_write_str(const char* buffer);
void uart_write_pstr(const char* buffer);

#endif
