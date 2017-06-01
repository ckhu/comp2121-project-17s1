; COMP2121 Assignment2
; Vending Machhine
; Group O3
; Author: Xiaowei Zhou
; z5108173
.include "m2560def.inc"
.include "Macros.asm"
.include "defines.asm"

.dseg
DebounceCounter: .byte 2
OutOfStock: .byte 2
ReturnCoin: .byte 1
ReturnCoinPattern: .byte 1
TempCounter: .byte 2
TempPrice: .byte 1
Quantity: .byte 18 ;(1byte quantity with 1 byte price£¬ 2-dimensional array)

.cseg
.org 0x0000
	jmp RESET
.org INT0addr ;push botton interrupts
	jmp PB0_INT
.org INT1addr
	jmp PB1_INT
.org OVF0addr ;timer 0
	jmp Timer0OVF
.org ADCCaddr ;POT interrupt
	jmp POT_INT


/*------below is lcd supporting functions------*/

lcd_command:
	out PORTF, lcd_out
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clear LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, lcd_out
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clear LCD_E
	rcall sleep_1ms
	lcd_clear LCD_RS
	ret


lcd_wait:
	push lcd_out
	clr lcd_out
	out DDRF, lcd_out
	out PORTF, lcd_out
	lcd_set LCD_RW

lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in lcd_out, PINF
	lcd_clear LCD_E
	sbrc lcd_out, 7
	rjmp lcd_wait_loop
	lcd_clear LCD_RW
	ser lcd_out
	out DDRF, lcd_out
	pop lcd_out
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4

sleep_1ms:
		push r24
		push r25
		ldi r25, high(DELAY_1MS)
		ldi r24, low(DELAY_1MS)
delayloop_1ms:
		sbiw r25:r24, 1
		brne delayloop_1ms
		pop r25
		pop r24
		ret

sleep_5ms:
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		ret

sleep_30ms:
		rcall sleep_5ms
		rcall sleep_5ms
		rcall sleep_5ms
		rcall sleep_5ms
		rcall sleep_5ms
		rcall sleep_5ms
		ret

/*-----lcd command finished-----*/
RESET:
	;initialise stack pointer
	ldi YL, low(RAMEND)
	ldi YH, high(RAMEND)
	out SPH, YH
	out SPL, YL

	;initialise keyboard
	ldi temp, PORTLDIR
	sts DDRL, temp

	;initialise counters
	clear DebounceCounter
	clear OutOfStock
	clear TempCounter

	;initialise Push Buttons
	clr temp
	out DDRB, temp
	out PORTB, temp

	;initialise LED
	ser temp
	out DDRC, temp ;PORTC for bottom 8
	out DDRG, temp ;PORTG for top 2
	clr temp
	out PORTC, temp
	out PORTG, temp

	;initialise LCD
	ser temp
	out DDRA, temp
	out DDRF, temp

	clr temp
	out PORTA, temp
	out PORTF, temp	

	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001100 ; Cursor on, bar, no blink

	do_lcd_data '2'
	do_lcd_data '1'
	do_lcd_data '2'
	do_lcd_data '1'
	do_lcd_data ' '
	do_lcd_data '1'
	do_lcd_data '7'
	do_lcd_data 's'
	do_lcd_data '1'
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data 'O'
	do_lcd_data '3'

	do_lcd_command 0b11000000 ;move to next line

	do_lcd_data 'V'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 'd'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'g'
	do_lcd_data ' '
	do_lcd_data 'M'
	do_lcd_data 'a'
	do_lcd_data 'c'
	do_lcd_data 'h'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'e'

	rjmp main ;go main

loop: rjmp loop ; infinite loop

/*--------------Timer functions-----------*/

makeDebounce: ; main debounce function
	lds r24, DebounceCounter
	lds r25, DebounceCounter+1
	adiw r25:r24, 1

	cpi r24, low(3906) ;time: 500ms
	ldi temp, high(3906)
	cpc r25, temp
	brne not500ms

	clear DebounceCounter ;clear counter
	cpi waitStatus, COIN_RETURN_READY
	breq CoinReturnInitialise
	cpi debounceStatus, MAIN_KEYPAD_DISABLED
	breq CoinReturn
	cpi debounceStatus, COIN_RETURN
	breq CoinReturn
	clr debounceStatus ;set debounce status to 0 
	;to enable keypad for new input

	rjmp EndIF ;finish debounce, end timer

not500ms:
	sts DebounceCounter, r24
	sts DebounceCounter+1, r25
	cpi waitStatus, ADMIN_ABORT
	breq goEndIF
	cpi debounceStatus, MAIN_KEYPAD_DISABLED ;if keypad is main disabled, some other work need to check
	breq checkStatusCont
	rjmp EndIF

CoinReturnInitialise:
	clr waitStatus ;reset wait status

CoinReturn:
	push temp
	lds temp, ReturnCoin
	cpi temp, 0 ;if returncoin = 0
	breq CoinReturnFinish ;finish return
	cpi debounceStatus, COIN_RETURN ;if debounce is coin return
	breq MotorReturn ;go return coin
	dec temp ;return one coin, temp--
	sts ReturnCoin, temp ;store remaining coins to dseg

	lds temp, ReturnCoinPattern ;load pattern for coins
	lsr temp ;right shift (coin-1)
	sts ReturnCoinPattern, temp ;store back
	out PortC, temp; output to LED

	ldi debounceStatus, COIN_RETURN ;debounce status set to coin return
	ldi temp, 1<<PE4
	out PORTE, temp ;turn motor
	pop temp
	rjmp makeDebounce

CoinReturnFinish:
	clr debounceStatus ; reset debounce
	clr temp
	ldi temp, (0<<PE4)
	out PORTE, temp
	pop temp
	rjmp EndIF ;finish coin return, go end timer

MotorReturn:
	ldi debounceStatus, MAIN_KEYPAD_DISABLED ;disable keypad (important))
	ldi temp, 0<<PE4
	out PORTE, temp
	pop temp
	rjmp makeDebounce

;check if '#' pressed, what to do next
HashPressAdminCheck: ;switch()
	cpi debounceStatus, ADMIN_ABORT ; if aborted from admin mode, go select items
	breq goSelectItem
	cpi debounceStatus, ADMIN_MODE ; if in admin mode, end timer
	breq goEndIF
	cpi debounceStatus, WAIT_ADMIN_MODE ; if waiting admin mode, go debounce
	breq goMakeDebounce
	cpi debounceStatus, GENERAL_DEBOUNCE ; if call for general debounce, go debounce
	breq goMakeDebounce
	cpi debounceStatus, NORMAL_DISABLE ;if keypad disable normally, go debounce
	breq goMakeDebounce
	rjmp EndIF

 ;branch bridges
goMakeDebounce:
	rjmp makeDebounce
goEndIF:
	rjmp EndIF
goTurnOnLED:
	rjmp LED_On
goOutOfStock:
	rjmp intOutOfStock

Timer0OVF: ;timer 0
	in temp, SREG
	push temp
	push YH
	push YL
	push r25
	push r24 ;push conflict registers

checkStatus: ;switch()
	cpi waitStatus, ADMIN_ABORT ;if admin aborted, make a debounce
	breq goMakeDebounce
	cpi waitStatus, COIN_RETURN ; if coins returned, select new item
	breq goSelectItem
	cpi debounceStatus, POT_INPUT ; if inserting by POT, make a debounce
	breq goMakeDebounce
	cpi debounceStatus, COIN_RETURN ; if coin returning, make debounce
	breq goMakeDebounce

checkStatusCont: ;switch()
	cpi waitStatus, ADMIN_MODE ; if already in admin mode, debounce
	breq goMakeDebounce
	cpi waitStatus, DELIVERY_ITEM ; if ready to delivery, go delivery
	breq ItemDelivery
	cpi waitStatus, WAIT_ADMIN_MODE ; if waiting for admin mode, check hash pressed
	breq HashPressAdminCheck
	cpi waitStatus, TITLE ; if want go back to title screen
	breq Title_Screen ;go title check
	cpi debounceStatus, STAR_PRESSED ;if star pressed
	breq Title_Screen ;go title check
	cpi waitStatus, OUT_OF_STOCK ; if out of stock
	breq goTurnOnLED ;flash LED
	cpi waitStatus, LED_FLASH ;if LED fiashing
	breq goOutOfStock ;go out of stock (to make loop)
	cpi waitStatus, POT_INPUT ;if POT insertion coins
	breq POTInputCheck ;check hashes
	cpi debounceStatus, NORMAL_DISABLE ;if keypad in normal disable, 
	breq goMakeDebounce ;go debounce

	;default:
	;clear counters
	clr counter
	clear TempCounter

	rjmp EndIF ;end timer

goSelectItem:
	rjmp SelectItem

POTInputCheck:
	cpi debounceStatus, LED_FLASH
	breq goEndIf ;if led flashing, end timer
	adiw ZH:ZL, 1 ;use Z as timer counting
	cpi ZL, low(390) ;50ms delay
	ldi temp, high(390)
	cpc ZH, temp
	brne not50ms
	 ;set up POT 
	ldi temp, (3<<REFS0 | 0<<ADLAR | 0<<MUX0)
	sts ADMUX, temp
	ldi temp, (1<<MUX5)
	sts ADCSRB, temp
	ldi temp, (1<<ADEN | 1<<ADSC | 1<<ADIE | 5<<ADPS0)
	sts ADCSRA, temp
	clr ZH
	clr ZL
	rjmp EndIF ;end timer

not50ms: 
	rjmp EndIF

ItemDelivery:
	ser temp
	out PORTC, temp ;set up led
	out PORTG, temp
	ldi waitStatus, LED_FLASH ;set up led wait status
	rjmp intOutOfStock ;go interrupt out of stack to flash
	;since the flashing is same, simply use same function

Title_Screen:
	cpi debounceStatus, NORMAL_DISABLE ;if keypad presssed, interrupt and go select item
	breq goSelectItem
	lds r24, TempCounter ;use r25:r24 as timer counting
	lds r25, TempCounter+1
	adiw r25:r24, 1
	cpi r24, low(7812) ;count 1 sec
	ldi temp, high(7812)
	cpc r25, temp
	brne not1s
	clear TempCounter
	cpi debounceStatus, STAR_PRESSED ;if pressing star
	breq checkEnterAdminMode ;check to enter admin mode
	cpi waitStatus, TITLE ;if still wait on Title page
	breq wait3Sec ;wait 3 sec if no interrupt

	rjmp EndIF

not1s:
	sts TempCounter, r24
	sts TempCounter+1, r25
	rjmp EndIF

wait3Sec:
	inc counter
	cpi counter, 3
	breq is3Sec ;if already 3 sec, go is3Sec
	rjmp EndIF

is3Sec: ;already 3 sec with no interrupts
	clr waitStatus
	clr debounceStatus
	clr counter
	;clear status and counter for recording 3 sec
	;set up motor
	in temp, PORTE
	ldi temp, 0<<PE4
	out PORTE, temp
	;go to select item
	rjmp SelectItem

checkEnterAdminMode:
	clr debounceStatus
	inc counter
	cpi counter, 5 ;if already 5 sec, go is5Sec
	breq is5Sec
	rjmp EndIF

is5Sec: ;already 5 sec * pressed,
	clr debounceStatus
	ldi waitStatus, ADMIN_MODE ;load admin mode wait status
	clr counter ;clear counter for recording 5 sec
	rjmp EndIF

; turn all 10 LEDs on
Onot500ms:
	sts OutOfStock, r24
	sts OutOfStock+1, r25
	rjmp EndIF

LED_On:
	ldi temp, 0xFF
	out PORTG, temp
	out PORTC, temp
	ldi waitStatus, LED_FLASH
	
intOutOfStock: ;out of stock interrupt (flashing LED)
	lds r24, OutOfStock ;use OutOfStock time counter
	lds r25, OutOfStock+1
	adiw r25:r24, 1
	cpi r24, low(3906) ;flash every 500ms
	ldi temp, high(3906)
	cpc r25, temp
	brne Onot500ms
	clear OutOfStock

LED_Flash_check:
	cpi counter, 5 ; (5+1)*500ms = 3 sec
	breq is3Sec ;if reached, go to is 3 sec
	inc counter ;else, increase counter
	mov temp, counter
	andi temp, 0b00000001 ;mask temp
	cpi temp, 0 ;if temp is even
	breq LED_On ;turn on led
	clr temp ;else
	out PORTC, temp ;turn off
	out PORTG, temp
	rjmp EndIF

;admin mode functions
InventoryNumberPlus:
	;if no PB pressed, go back
	cpi debounceStatus, WAIT_ADMIN_MODE
	breq funcReturn
	cpi debounceStatus, ADMIN_MODE
	breq funcReturn

	cpi quantityTemp, 10 ;if reached maximum number
	breq funcReturn ;return
	push temp
	in temp, SREG
	push temp
	push YL
	push YH
	inc quantityTemp ;increase number
	sbiw Y, 1 ;move to quantity
	st Y, quantityTemp ;store new number
	ldi debounceStatus, ADMIN_MODE ;back to admin_mode
	pop YH
	pop YL
	pop temp
	out SREG, temp
	pop temp
	reti

InventoryNumberMinus:
	;if no PB pressed, go back
	cpi debounceStatus, WAIT_ADMIN_MODE
	breq funcReturn
	cpi debounceStatus, ADMIN_MODE
	breq funcReturn

	cpi quantityTemp, 0 ;if reached minimum number
	breq funcReturn ;return
	push temp
	in temp, SREG
	push temp
	push YL
	push YH
	dec quantityTemp ;decrease number
	sbiw Y, 1 ;move to quantity
	st Y, quantityTemp ;store new number
	ldi debounceStatus, ADMIN_MODE ;back to admin_mode
	pop YH
	pop YL
	pop temp
	out SREG, temp
	pop temp
funcReturn:
	reti

PB0_INT:
	cpi waitStatus, WAIT_ADMIN_MODE
	breq InventoryNumberPlus
	rjmp End_PB_INT

PB1_INT:
	cpi waitStatus, WAIT_ADMIN_MODE
	breq InventoryNumberMinus

End_PB_INT:
	cpi debounceStatus, PB_DISABLE ;check if still debouncing
	brne funcReturn
	push temp
	in temp, SREG
	push temp
	clear OutOfStock
	clr temp ;turn off led
	out PORTC, temp
	out PORTG, temp
	pop temp
	out SREG, temp
	pop temp
	rjmp SelectItem

POT_INT:
	cpi debounceStatus, LED_FLASH
	breq POT_Cont ;if LED_FLASHING, POT should not work
	push temp
	in temp, SREG
	push temp
	push r25
	push r24
	lds r24, ADCL
	lds r25, ADCH
	cpi r24, 0
	ldi temp, 0
	cpc r25, temp 
	breq POT_MIN;if reached min

	cpi r24, 0b11111111
	ldi temp, 3
	cpc r25, temp
	breq POT_MAX;if reached max

POT_Cont: ;finish pot, return
	pop r24
	pop r25
	pop temp
	out SREG, temp
	pop temp
	reti
	
POT_MIN: ;reached minimum
	cpi quantityTemp, 0 ;if quantityTemp is not 0, maximum not reached
	brne POT_Cont ;;do nothing
	inc counter
	ldi quantityTemp, 1 ;if reached minimun, quantityTemp set to 1
	cpi counter, 2
	brne POT_Cont
	ldi debounceStatus, LED_FLASH ;flash led
	rjmp POT_Cont ;finish input

POT_MAX:
	cpi quantityTemp, 1;if quantityTemp is not 1, minimum not reached
	brne POT_Cont ;do nothing
	clr quantityTemp ;if reached maximum, quantityTemp set to 0
	rjmp POT_Cont ;finish input

SelectItem:

	clr r15
	out PORTC, r15
	out PORTG, r15

	do_lcd_command 0b00000001 ; clear display

	do_lcd_data 'S'
	do_lcd_data 'e'
	do_lcd_data 'l'
	do_lcd_data 'e'
	do_lcd_data 'c'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'i'
	do_lcd_data 't'
	do_lcd_data 'e'
	do_lcd_data 'm'

	do_lcd_command 0b11000000 ; second line

	rcall sleep_5ms ;wait for LCD

	cpi debounceStatus, NORMAL_DISABLE
	breq moreDebounce ;interrupted title screen, more debounce to avoid keypad error

	cpi debounceStatus, ADMIN_ABORT
	breq Admin_abort_clear ;interrupted admin mode, clear counters used in admin mode

	cpi debounceStatus, PB_DISABLE
	breq PB_break_clear ;interrupted out of stock, clear counters used by push button

	ldi waitStatus, ADMIN_ABORT ;load wait status to be normal mode (not admin mode)
	rjmp EndIF

moreDebounce: ;do one more debounce
	clr waitStatus
	clr counter
	counter_clear
	rjmp makeDebounce

PB_break_clear: ;clear counters used by push button
	counter_clear
	clr counter
	clr debounceStatus
	clr waitStatus
	reti

Admin_abort_clear: ;clear counters used by admin mode
	counter_clear
	clr counter
	clr debounceStatus
	clr waitStatus
	rjmp EndIF ; finish timer

EndIF:
	pop r24
	pop r25
	pop YL
	pop YH
	pop temp
	out SREG, temp
	reti

/*--Timer based functions finished---*/
/*----------------main---------------*/

goAdminInit:
	rjmp AdminInitialise
goAdminShow:
	clr debounceStatus
	rjmp adminMode
goPOT:
	ldi debounceStatus, LED_FLASH
	rjmp POTInsertion
	
main:
	;reset statuss
	clr counter
	clr debounceStatus ;debounce initialise to false
	ldi waitStatus, TITLE ;wait initialise to TITLE

	;initialise timer interrupts
	clr temp
	out TCCR0A, temp
	ldi temp, (1<<CS01)
	out TCCR0B, temp ;prescaling 8
	ldi temp, (1<<TOIE0)
	sts TIMSK0, temp
	sei ;enable interrupts
	
	;initialise PB interrupts
	ldi temp, (1<<ISC01 | 1<<ISC11)
	sts EICRA, temp
	in temp, EIMSK
	ori temp, (1<<INT0 | 1<<INT1)
	out EIMSK, temp
	clr temp

	;initialise Quantity and price
	ldi YH, high(Quantity)
	ldi YL, low(Quantity)
QuantityLoop:
	inc temp
	st Y+, temp
	mov r15, temp
	andi temp, 1 ;mask temp to odd/even
	cpi temp, 1 ; if temp = 1, odd number
	breq input_price ; odd number price = 1
	ldi temp, 2
input_price:
	st Y+, temp
	mov temp, r15
	clr r15
	cpi temp, 9
	brlt QuantityLoop
	push counter ;need to modify
	clr counter
	pop counter


;Most main functions are looping in keypad
KeypadInitialise:
	ldi cmask, INITCOLMASK
	clr col
	clr temp
	clr numberTemp
	clr priceTemp

	cpi waitStatus, ADMIN_MODE ;if admin mode
	breq goAdminInit ;initialise admin
	

	;switch()
	;check all debounce status
	cpi debounceStatus, NORMAL_DISABLE ;keypad Disabled normally
	breq KeypadInitialise
	cpi debounceStatus, PB_DISABLE ;keypad Disabled by PB
	breq KeypadInitialise
	cpi debounceStatus, LED_FLASH ;keypad Disabled by POT
	breq goPOT
	cpi debounceStatus, ADMIN_MODE ;debouncing admin mode, show admin page
	breq goAdminShow
	cpi debounceStatus, WAIT_ADMIN_MODE ;keypad Disabled by waiting admin mode
	breq KeypadInitialise
	cpi debounceStatus, GENERAL_DEBOUNCE
	breq KeypadInitialise
	

	;check all wait status
	cpi waitStatus, OUT_OF_STOCK ;out of stock page, keypad disabled
	breq KeypadInitialise
	cpi waitStatus, LED_FLASH ;led flashing for out of stock, keypad disabled
	breq KeypadInitialise
	cpi waitStatus, COIN_RETURN ;coin returning, keypad disabled
	breq KeypadInitialise
	cpi waitStatus, ADMIN_ABORT ;aborting from admin, keypad disabled
	breq KeypadInitialise
	
	cpi debounceStatus, COIN_RETURN_READY
	breq KeypadInitialise

;Input check
col_check:
	cpi col, 4
	breq KeypadInitialise ;if no col pressed, scan again
	sts PORTL, cmask ;mask keypad
	ldi numberTemp, 0b11111111 ;load delay

delay_loop:
	dec numberTemp
	brne delay_loop ;delay until temp1 decrease to 0


	lds numberTemp, PINL ;;read keypad
	andi numberTemp, ROWMASK
	cpi numberTemp, 0xF ;check rows
	breq next_col ;if no row find, go next column
	ldi rmask, INITROWMASK ;load row mask for row check
	clr row

row_check:
	cpi row, 4
	breq next_col ;if already 4 rows, go next col
	mov priceTemp, numberTemp
	and priceTemp, rmask
	breq convert_key ;if key is found, go converting
	inc row ;else go next row
	lsl rmask
	rjmp row_check

next_col:
	lsl cmask ; left shift cmask to check next col
	inc col ; col number ++
	jmp col_check ; go back


;convert input to key
convert_key:
	cpi col, 3 ;if col 3 pressed, go letters
	breq input_letter

	cpi row, 3 ;if row 3 pressed (excepted col 3)
	breq input_symbol ;go symbols

	;else, we have numbers
	mov numberTemp, row
	lsl numberTemp
	add numberTemp, row
	add numberTemp, col
	subi numberTemp, -1 ;row*3+col+1 = input_key
	jmp convert_key_end

input_letter:
	cpi waitStatus, WAIT_ADMIN_MODE ;if in admin mode
	breq AdminOp ;go operations
	ldi debounceStatus, NORMAL_DISABLE ;else, disable scan normally
	jmp KeypadInitialise ;go back

AdminOP: ;already col 3
	cpi row, 0
	breq pressA
	cpi row, 1
	breq pressB
	cpi row, 2
	breq pressC
	;row 3 -> D is not used, just return
re_scan:
	ldi debounceStatus, NORMAL_DISABLE; disable scan normally
	jmp KeypadInitialise; go back

pressA: ;A, inc price by 1
	lds priceTemp, TempPrice
	cpi priceTemp, 3 ;if price reached maximun
	breq re_scan ;re scan key
	inc priceTemp ;else, increase price by 1
	st Y, priceTemp ;store back
	ldi debounceStatus, ADMIN_MODE ;go back to scan key with admin mode disable
	jmp KeypadInitialise

pressB: ;B, dec price by 1
	lds priceTemp, TempPrice
	cpi priceTemp, 1 ;if price reached minimun
	breq re_scan ;re scan key
	dec priceTemp ;else, decrease price by 1
	st Y, priceTemp ;store back
	ldi debounceStatus, ADMIN_MODE ;go back to scan key with admin mode disable
	jmp KeypadInitialise

pressC: ;C, quantity set to 0
	push temp
	push YL
	push YH
	sbiw Y, 1 ;move to quantity
	clr temp
	st Y, temp ;set quantity to zero
	pop YH
	pop YL
	pop temp
	ldi debounceStatus, ADMIN_MODE ;go back to scan key with admin mode disable
	jmp KeypadInitialise

input_symbol:
	cpi col, 0 ;if col 0
	breq pressStar ;press star
	cpi col, 1 ;if col 1
	breq press0 ;press 0
	cpi waitStatus, POT_INPUT ;else, press hash
	breq coinAbort ;if waiting coin insert, return coin
	cpi waitStatus, WAIT_ADMIN_MODE ;if in admin mode
	breq AdminModeAbort ;abort admin mode

press0:
	ldi debounceStatus, NORMAL_DISABLE ;disable scan
	jmp KeypadInitialise ;go back

pressStar: ; * for enter admin mode
	cpi waitStatus, 0 ;if nothing wait
	breq waitAdmin ;go wait admin mode
	ldi debounceStatus, NORMAL_DISABLE ;else, disable scan
	jmp KeypadInitialise ;go back

waitAdmin: ;wait admin mode
	ldi debounceStatus, STAR_PRESSED ;set debounce status to star mode
	jmp KeypadInitialise ;re scan

coinAbort: ;Coin aborted, ready to return coin
	ldi debounceStatus, MAIN_KEYPAD_DISABLED
	pop YH
	pop YL
	pop counter
	pop quantityTemp
	pop priceTemp
	pop numberTemp

	sts ReturnCoin, numberTemp
	sts ReturnCoinPattern, counter ;store counter to pattern for led out
	clr counter
	ldi waitStatus, COIN_RETURN ;set waiting status to coin return
	rjmp KeypadInitialise ;go back to scan key with coin return mode

AdminModeAbort: ;admin mode abort, ready to exit admin mode
	ldi debounceStatus, ADMIN_ABORT ;set debounce status to admin abort
	rjmp KeypadInitialise ;go back to scan key

convert_key_end:
	cpi waitStatus, POT_INPUT ;if POT inputing
	breq goBackKeypad ;keep disable scan but #
	ldi debounceStatus, NORMAL_DISABLE ;disable scan normally
	cpi waitStatus, TITLE ;if title screen,, interrupt it and go select item
	breq goBackKeypad ;go back
	cpi waitStatus, WAIT_ADMIN_MODE
	breq JMPAdminMode
	push numberTemp ;push the key result in stack
	rjmp findItem ;go find Item

goBackKeypad: jmp KeypadInitialise

JMPAdminMode:
	pop temp
	push numberTemp
	rjmp adminMode

AdminInitialise:
	ldi numberTemp, 1 ;admin mode initialise to start from Inventory 1
	ldi waitStatus, WAIT_ADMIN_MODE ;set wait status to admin mode
	push numberTemp

adminMode: ;enter admin mode
	pop numberTemp
	do_lcd_command 0b00000001 ;clear display
	do_lcd_data 'A'
	do_lcd_data 'd'
	do_lcd_data 'm'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data ' '
	do_lcd_data 'm'
	do_lcd_data 'o'
	do_lcd_data 'd'
	do_lcd_data 'e'
	do_lcd_data ' '
	do_lcd_data_reg numberTemp ;initialise to admin mode with item 1

	push numberTemp

findItem:
	ldi YH, high(Quantity) ;load quantity address to Y
	ldi YL, low(Quantity)
findItemLoop:
	dec numberTemp
	cpi numberTemp, 0
	breq goItemInStock ;item founded
	adiw Y, 2 ; else move to next
	rjmp findItemLoop ; check again

show9Pattern:
	ldi temp, 0xFF
	out PORTC, temp
	ldi temp, 8
	sub quantityTemp, temp ;change 9/10 to 1/2
	mov temp, quantityTemp
	ori temp, 1 ;1->light 1 led, 2->linght 2 led
	out PORTG, temp
	pop quantityTemp
	rjmp adminInventory

InventoryLED:
	clr temp
	out PORTC, temp
	out PORTG, temp
	cpi quantityTemp, 0
	breq adminInventory
	push quantityTemp

showInventoryPattern:
	cpi quantityTemp, 9
	brge show9Pattern
	lsl temp
	inc temp ;temp *2 +1
	dec quantityTemp ;quantityTemp --
	cpi quantityTemp, 0 ;if quantityTemp != 0
	brne showInventoryPattern ;loop again
	out PORTC, temp ;else, output to LED

	pop quantityTemp

adminInventory:
	do_lcd_command 0b11000000 ;second line
	cpi quantityTemp, 10
	brlt show_less_10
	do_lcd_data '1'
	do_lcd_data '0'
	rjmp show_eq_10

goItemInStock: rjmp itemInStock

show_less_10:
	do_lcd_data_reg quantityTemp ;output quantity
	do_lcd_data ' '
show_eq_10:
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data '$'
	lds priceTemp, TempPrice ;load price
	do_lcd_data_reg priceTemp ;output price
	ldi debounceStatus, WAIT_ADMIN_MODE; set debounce status to admin mode
	rjmp KeypadInitialise ; go back

goInventoryLED: rjmp InventoryLED

itemOutOfStock:
	pop numberTemp
	do_lcd_command 0b00000001 ;clear display

	do_lcd_data 'O'
	do_lcd_data 'u'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'o'
	do_lcd_data 'f'
	do_lcd_data ' '
	do_lcd_data 's'
	do_lcd_data 't'
	do_lcd_data 'o'
	do_lcd_data 'c'
	do_lcd_data 'k'

	do_lcd_command 0b11000000 ; second line
	do_lcd_data_reg numberTemp ;output item number

	rcall sleep_5ms

	clr counter
	ldi debounceStatus, PB_DISABLE ; disable keypad
	ldi waitStatus, OUT_OF_STOCK ; set wait status to out of stock to flash led.
	rjmp KeypadInitialise ;go back

itemInStock:
	ld temp, Y+ ;load quantity
	mov quantityTemp, temp ;COPY quantity to quantityTemp
	ld priceTemp, Y ;load price
	sts TempPrice, priceTemp ;store price to TempPrice
	cpi waitStatus, WAIT_ADMIN_MODE ;if in admin mode
	breq goInventoryLED ;show on led
	cpi temp, 0 ;if quantity = 0
	breq itemOutOfStock ;out of stock
	clr numberTemp

CoinInsertion:
	
	do_lcd_command 0b00000001 ; clear display

	do_lcd_data 'I'
	do_lcd_data 'n'
	do_lcd_data 's'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'c'
	do_lcd_data 'o'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 's'
	
	do_lcd_command 0b11000000 ; second line for coin remaining
	do_lcd_data_reg priceTemp ; output coin remaining

	push numberTemp
	push priceTemp
	push quantityTemp
	push counter
	push YL
	push YH ;push conflict registers
	
	;clear counters
	clr priceTemp
	clr quantityTemp
	clr counter

;to insert coins, initialise POT
POTInitialise:
	ldi waitStatus, POT_INPUT ;set wait status to POT input
	clr debounceStatus ;reset debounce

POTInsertion:
	cpi debounceStatus, LED_FLASH ; if insert
	brne goBackInitialise
	
	ldi temp, (0<<ADEN | 1<<ADSC | 0<<ADIE)
	sts ADCSRA, temp
	clr debounceStatus
	pop YH
	pop YL
	pop counter
	pop quantityTemp
	pop priceTemp
	pop numberTemp
	inc numberTemp

	lsl counter ;counter stored number of coins on led
	inc counter ;counter *2+1
	out PORTC, counter ;output to LED

	subi priceTemp, 1 ; coin needed --
	cpi priceTemp, 0 ;if still need coins
	brne goCoinInsertion ;go insertion
	clr waitStatus ;else, clear wait status and deliver item
	rjmp deliveryItem

goBackInitialise: rjmp KeypadInitialise
goCoinInsertion: rjmp coinInsertion

deliveryItem:
	subi quantityTemp, 1 ;item quantity-1
	st -Y, quantityTemp ;store to dseg
	clr counter ;clear coin counter

	do_lcd_command 0b00000001; clear display

	do_lcd_data 'D'
	do_lcd_data 'e'
	do_lcd_data 'l'
	do_lcd_data 'i'
	do_lcd_data 'v'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'g'
	do_lcd_data ' '
	do_lcd_data 'i'
	do_lcd_data 't'
	do_lcd_data 'e'
	do_lcd_data 'm'

	do_lcd_command 0b11000000 ;second line

	ldi temp, (1<<PE4) ;set up motor to deliver
	out DDRE, temp
	out PORTE, temp
	ldi waitStatus, DELIVERY_ITEM ;set wait status to delivery
	ldi debounceStatus, NORMAL_DISABLE ; disable keypad
	rjmp KeypadInitialise

/*-------------program finished----------------*/