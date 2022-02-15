;-------------------------------------------------------------------------------
;Encabezado
;-------------------------------------------------------------------------------
    
; Archivo: Prelab_main.s
; Dispositivo: PIC16F887
; Autor: José Fernando de León González
; Compilador:  pic-as (v2.30), MPLABX v5.40
;
; Programa: Contador binario de 4 bits utilizando push-buttons e interrupciones y contador binario de 4 bits utilizando el timer0 e interrupciones
; Hardware: Leds y resistencias en el puerto A y puerto D, pushbuttons en el puerto B.
;
; Creado: 7/02/22
; Última modificación: 7/02/22
    
PROCESSOR 16F887

;-------------------------------------------------------------------------------
;Palabras de configuración 
;-------------------------------------------------------------------------------
    
; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF            ; Brown Out Reset Selection bits (BOR enabled)
  CONFIG  IESO = OFF             ; Internal External Switchover bit (Internal/External Switchover mode is enabled)
  CONFIG  FCMEN = OFF            ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is enabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

;-------------------------------------------------------------------------------
;Librerías incluidas
;-------------------------------------------------------------------------------
  
#include <xc.inc>
  
restart_tmr0 macro
    BANKSEL TMR0        ; banco 00
    MOVLW 60            ; cargar valor inicial a W
    MOVWF TMR0          ; cargar el valor inicial al TIMER0
    bcf T0IF            ; limpiar la bandera  de overflow del TIMER0
    endm
      
;-------------------------------------------------------------------------------
;Variables
;-------------------------------------------------------------------------------
  
PSECT udata_shr ; Variables en la memoria RAM compartida entre bancos
    counter: DS 1 ;1 byte reservado (variable para aumentar la cantidad de ciclos del TIMER0)
    W_TEMP: DS 1 ; 1 byte reservado (W Temporal)
    STATUS_TEMP: DS 1 ; 1 byte reservado (STATUS Temporal)
    
;-------------------------------------------------------------------------------
;Vector Reset
;-------------------------------------------------------------------------------

PSECT VectorReset, class = CODE, abs, delta = 2 ; delta = 2: Las instrucciones necesitan 2 localidades para ejecutarse & abs = absolute: indicamos que contamos a partir de 0x0000
ORG 00h  ; la localidad del vector reset es 0x0000
 
VectorReset:
    PAGESEL main
    GOTO main
;-------------------------------------------------------------------------------
;Vector de interrupción
;-------------------------------------------------------------------------------
ORG 04h	    ; posición 0004h para las interrupciones
push:
    MOVWF W_TEMP
    SWAPF STATUS, W
    MOVWF STATUS_TEMP
isr:
    btfsc T0IF
    call int_T0
    call limit_checkD
    btfsc   RBIF
    call int_iocb
    call push_limit_checkA
pop:
    SWAPF STATUS_TEMP, W
    MOVWF STATUS
    SWAPF W_TEMP, F
    SWAPF W_TEMP, W
    retfie
;-------------------------------------------------------------------------------
;Subrutinas de interrupción
;-------------------------------------------------------------------------------
int_iocb:
    banksel PORTB
    btfss PORTB, 0
    incf PORTA
    btfss PORTB, 1
    decf PORTA
    BCF RBIF
    return
    
push_limit_checkA:
    BTFSS PORTA, 4	    ;chequeamos si el quinto bit de PORTD está en 1
    goto $+11                ;NO: salimos de la subrutina
    BTFSS PORTA, 7	    ;SÍ, chequeamos si el octavo bit de PORTD está en 1
    goto $+2		    ;NO: Limpiamos el puerto 
    goto $+3                ;SÍ: Limpiamos el puerto y seteamos el nibble low
    CLRF PORTA		    
    goto $+6 
    CLRF PORTA		    
    BSF PORTA, 0
    BSF PORTA, 1
    BSF PORTA, 2
    BSF PORTA, 3
    
    return
int_T0:
    
    DECFSZ counter        ; decrementamos el contador y verificamos si se vuelve 0
    goto $+4	          ;NO: salimos de la subrutina
    call restart_counter  ;SÍ: reiniciamos el contador y seguimos la subrutina
    INCF PORTD 
    restart_tmr0
    return

restart_counter:
    MOVLW 10
    MOVWF counter
    
    return

limit_checkD:
    BTFSS PORTD, 4	    ;chequeamos si el quinto bit de PORTD está en 1
    goto $+11                ;NO: salimos de la subrutina
    BTFSS PORTD, 7	    ;SÍ, chequeamos si el octavo bit de PORTD está en 1
    goto $+2		    ;NO: Limpiamos el puerto 
    goto $+3                ;SÍ: Limpiamos el puerto y seteamos el nibble low
    CLRF PORTD		    
    goto $+6 
    CLRF PORTD		    
    BSF PORTD, 0
    BSF PORTD, 1
    BSF PORTD, 2
    BSF PORTD, 3
    
    return

;-------------------------------------------------------------------------------
;Tabla para display de siete segmentos
;-------------------------------------------------------------------------------

/* 
PSECT table, class = CODE, abs, delta = 2
ORG 100h 

table:
    CLRF PCLATH
    BSF PCLATH, 0           ; PCLATH en 01
    ANDLW 0X0F
    ADDWF PCL               ; PC = PCLATH + PCL | Sumamos W al PCL para seleccionar un dato en la tabla
    retlw 00111111B         ; 0
    retlw 00000110B         ; 1
    retlw 01011011B         ; 2
    retlw 01001111B         ; 3
    retlw 01100110B         ; 4
    retlw 01101101B         ; 5
    retlw 01111101B         ; 6
    retlw 00000111B         ; 7
    retlw 01111111B         ; 8 
    retlw 01101111B         ; 9
    retlw 01110111B         ; A
    retlw 01111100B         ; b
    retlw 00111001B         ; C
    retlw 01011110B         ; D
    retlw 01111001B         ; C
    retlw 01110001B         ; F
*/
;-------------------------------------------------------------------------------
;main (configuración)
;-------------------------------------------------------------------------------

main:			    
    MOVLW 10
    MOVWF counter
    call config_tmr0
    call config_ports
    call config_clock
    call config_iocrb
    call config_int_enable
    
    banksel PORTA
    			    ;---------------------------------------------------
			    ;TEMPORIZACIÓN TIMER0: 100 ms = 4*4us*(256-60)*32
			    ;---------------------------------------------------
    
;-------------------------------------------------------------------------------
;Loop
;-------------------------------------------------------------------------------

loop:
    
    goto loop
;-------------------------------------------------------------------------------
;subrutinas
;-------------------------------------------------------------------------------
config_iocrb:
    banksel TRISA
    BSF IOCB, 0
    BSF IOCB, 1	    ; seteamos los bits 0 y 1 del puerto B como interrupt on change
    
    banksel PORTA
    MOVF PORTB, W   ; Al leer termina condición de mismatch
    BCF RBIF
    
    return
config_ports:
    
    banksel ANSEL       ; banco 11
    CLRF ANSEL		; pines digitales
    CLRF ANSELH
    
    banksel TRISA       ; banco 01
    CLRF TRISA		; PORTA como salida
    CLRF TRISD		;PORTD como salida
    
    BSF  TRISB0
    BSF  TRISB1         ; pines 1 & 2 del puerto B como entradas
    
    BCF OPTION_REG, 7	;Habilitar Pull-ups
    
    banksel PORTA       ; banco 00
    CLRF PORTA		; limpiamos PORTA
    CLRF PORTD		; limpiamos PORTD
    return
    
config_clock:
    banksel OSCCON      ;banco 01
    BCF IRCF2
    BSF IRCF1
    BCF IRCF0           ; IRCF <2:0> -> 010 250 kHz
    
    BSF SCS             ;reloj interno
    
    return
    
config_tmr0:
    banksel TRISA  ; banco 01
    BCF T0CS            ; TIMER0 como temporizador
    BCF PSA             ; Prescaler a TIMER0
    BSF PS2
    BCF PS1
    BCF PS0             ; PS<2:0> -> preescaler 100 1:32
    
    restart_tmr0
    
    return



config_int_enable:
    BSF GIE ; INTCON
    BSF RBIE
    BCF RBIF
    
    BSF T0IE
    BCF T0IF
    
    return
END


