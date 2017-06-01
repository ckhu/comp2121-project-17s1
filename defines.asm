; COMP2121 Assignment2
; Vending Machhine
; Group O3
; Author: Xiaowei Zhou
; z5108173

;general registers
.def temp = r16
.def debounceStatus = r17 ;debouce status
.def waitStatus = r18 ;wait status
.def lcd_out = r19 ;lcd output register
.def counter = r20 ;general counter

;keypad registers
.def cmask = r21
.def rmask = r22
.def col = r23
.def row = r24

;external temp registers
.def numberTemp = r25 ;external temp register
#define priceTemp XL ;avoid variable definition duplicate
#define quantityTemp XH

;Keypad constants
.equ PORTLDIR = 0b11110000
.equ INITCOLMASK = 0b11101111
.equ INITROWMASK = 0b00000001
.equ ROWMASK = 0b00001111

;LCD constants
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

;wait and debounce status in normal mode
.equ TITLE = 1 ; for wait
.equ NORMAL_DISABLE = 1 ; for debounce
.equ OUT_OF_STOCK = 2 ; for wait
.equ PB_DISABLE = 2 ; for debounce
.equ LED_FLASH = 3
; POT_INPUT and MAIN_KEYPAD_DISABLED performs the same
.equ POT_INPUT = 6
.equ MAIN_KEYPAD_DISABLED = 6
.equ STAR_PRESSED = 7 ;for debounce
.equ DELIVERY_ITEM = 7 ;for wait
.equ COIN_RETURN = 8 ;wait and debounce
; the debounce of COIN_RETURN_READY and ADMIN_ABORT performs the same
.equ COIN_RETURN_READY = 9 ;debounce
.equ ADMIN_ABORT = 9 ;wait and debounce
.equ GENERAL_DEBOUNCE = 10 ;debounce

;wait and debounce status in admin mode
.equ ADMIN_MODE = 11
.equ WAIT_ADMIN_MODE = 12
