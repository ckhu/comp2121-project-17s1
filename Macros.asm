; COMP2121 Assignment2
; Vending Machhine
; Group O3
; Author: Xiaowei Zhou
; z5108173

;macros
.macro do_lcd_command
	ldi lcd_out, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi lcd_out, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_reg ;output lcd data from register
	mov lcd_out, @0
	subi lcd_out, -'0'
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clear
	cbi PORTA, @0
.endmacro

.macro clear
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr temp
	st Y+, temp
	st Y, temp
.endmacro

.macro counter_clear
	clear OutOfStock
	clear TempCounter
	clear DebounceCounter
.endmacro
