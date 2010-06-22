#ifndef _KS0066_H_
#define _KS0066_H_

//********** instructions **********************************
// instructions RS=0, R/W=0

#define CLEAR_DISPLAY 0x01


#define RETURN_HOME 0x02


#define ENTRY_MODE_BASIC 0x04

// ENTRY_MODE_ID: cursor right,inc -> else cursor left, dec
#define ENTRY_MODE_ID 0x02
// ENTRY_MODE_SHIFT: moves entire screen
#define ENTRY_MODE_SHIFT 0x01


#define DISPLAY_CONTROL_BASIC 0x08

#define DISPLAY_ON 0x04
#define CURSOR_ON 0x02
#define CURSOR_BLINK 0x01


#define SHIFT_BASIC 0x10

#define SHIFT_LEFT_DEC 0x00
#define SHIFT_RIGHT_INC 0x04
#define SHIFT_ALL_LEFT 0x08
#define SHIFT_ALL_RIGHT 0x0C


#define FUNCTION_SET_BASIC 0x20

// FS_BUS_MODE: 8 bit mode -> else 4 bit mode
#define FS_BUS_MODE 0x10
// FS_TWO_LINE: enables 2-line-mode -> else 1-line-mode
#define FS_TWO_LINE 0x08
// FS_FONT_5X11: enables 5x11 font -> else 5x8
#define FS_FONT_5X11 0x04


#define SET_DDRAM_ADDR _BV(7)

#define DDRAM_ADDR_MASK 0x7f


#define SET_CGRAM_ADDR 0x40

#define CGRAM_ADDR_MASK 0x3f

#define DATA_SIG_WAIT_US 1
#define SHORT_WAIT_US 80
#define LONG_WAIT_MS 5
#define INIT_WAIT_MS 45

#define BUSY_FLAG 0x80

#endif
