; utils.s
; Desenvolvido para a placa EK-TM4C1294XL
; Código que apresenta algumas funcionalidades:
; - Altera a frequência do barramento usando o PLL
; - Configura o Systick para utilizar delays precisos

; Editado por Guilherme Peron
; 15/03/2018
; 26/08/2020

; Copyright 2014 by Jonathan W. Valvano, valvano@mail.utexas.edu

; -------------------------------------------------------------------------------------------------------------------------
; PLL
; -------------------------------------------------------------------------------------------------------------------------
; A frequência do barramento será 80MHz
; Representa o divisor para inicializar o PLL para a frequência desejada
; Frequência do barramento é 480MHz/(PSYSDIV+1) = 480MHz/(5+1) = 80 MHz
PSYSDIV                       EQU 5

SYSCTL_RIS_R                  EQU 0x400FE050
SYSCTL_RIS_MOSCPUPRIS         EQU 0x00000100  ; MOSC Power Up Raw Interrupt Status
SYSCTL_MOSCCTL_R              EQU 0x400FE07C
SYSCTL_MOSCCTL_PWRDN          EQU 0x00000008  ; Power Down
SYSCTL_MOSCCTL_NOXTAL         EQU 0x00000004  ; No Crystal Connected
SYSCTL_RSCLKCFG_R             EQU 0x400FE0B0
SYSCTL_RSCLKCFG_MEMTIMU       EQU 0x80000000  ; Memory Timing Register Update
SYSCTL_RSCLKCFG_NEWFREQ       EQU 0x40000000  ; New PLLFREQ Accept
SYSCTL_RSCLKCFG_USEPLL        EQU 0x10000000  ; Use PLL
SYSCTL_RSCLKCFG_PLLSRC_M      EQU 0x0F000000  ; PLL Source
SYSCTL_RSCLKCFG_PLLSRC_MOSC   EQU 0x03000000  ; MOSC is the PLL input clock source
SYSCTL_RSCLKCFG_OSCSRC_M      EQU 0x00F00000  ; Oscillator Source
SYSCTL_RSCLKCFG_OSCSRC_MOSC   EQU 0x00300000  ; MOSC is oscillator source
SYSCTL_RSCLKCFG_PSYSDIV_M     EQU 0x000003FF  ; PLL System Clock Divisor
SYSCTL_MEMTIM0_R              EQU 0x400FE0C0
SYSCTL_DSCLKCFG_R             EQU 0x400FE144
SYSCTL_DSCLKCFG_DSOSCSRC_M    EQU 0x00F00000  ; Deep Sleep Oscillator Source
SYSCTL_DSCLKCFG_DSOSCSRC_MOSC EQU 0x00300000  ; MOSC
SYSCTL_PLLFREQ0_R             EQU 0x400FE160
SYSCTL_PLLFREQ0_PLLPWR        EQU 0x00800000  ; PLL Power
SYSCTL_PLLFREQ0_MFRAC_M       EQU 0x000FFC00  ; PLL M Fractional Value
SYSCTL_PLLFREQ0_MINT_M        EQU 0x000003FF  ; PLL M Integer Value
SYSCTL_PLLFREQ0_MFRAC_S       EQU 10
SYSCTL_PLLFREQ0_MINT_S        EQU 0
SYSCTL_PLLFREQ1_R             EQU 0x400FE164
SYSCTL_PLLFREQ1_Q_M           EQU 0x00001F00  ; PLL Q Value
SYSCTL_PLLFREQ1_N_M           EQU 0x0000001F  ; PLL N Value
SYSCTL_PLLFREQ1_Q_S           EQU 8
SYSCTL_PLLFREQ1_N_S           EQU 0
SYSCTL_PLLSTAT_R              EQU 0x400FE168
SYSCTL_PLLSTAT_LOCK           EQU 0x00000001  ; PLL Lock

        AREA    |.text|, CODE, READONLY, ALIGN=2
        THUMB
        EXPORT  PLL_Init

;------------PLL_Init------------
; Configura o sistema para utilizar o clock do PLL
; Entrada: Nenhum
; Saída: Nenhum
; Modifica: R0, R1, R2, R3
PLL_Init
    ; Capítulo 5 do Datasheet
    ; 1) Depois que a configuração for pronta, o PIOSC provê o clock do sistema. Este,
    ;    passo garante que se a função já tenha sido chamada antes, o sistema desabilite
    ;    o clock do PLL antes de configurá-lo novamente.
    LDR R1, =SYSCTL_RSCLKCFG_R                 ; R1 = SYSCTL_RSCLKCFG_R (ponteiro)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_RSCLKCFG_USEPLL        ; R0 = R0&~SYSCTL_RSCLKCFG_USEPLL (limpar o bit USEPLL bit para não clockar pelo PLL)
    STR R0, [R1]                               ; [R1] = R0
    ; 2) Ligar o MOSC limpando o bit NOXTAL bit no registrador SYSCTL_MOSCCTL_R.
    ; 3) Como o modo cristal é requerido, limpar o bit de PWRDN. O datasheet pede 
	;     para fazer estas duas operações em um único acesso de escrita ao SYSCTL_MOSCCTL_R.
    LDR R1, =SYSCTL_MOSCCTL_R                  ; R1 = SYSCTL_MOSCCTL_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_MOSCCTL_NOXTAL         ; R0 = R0&~SYSCTL_MOSCCTL_NOXTAL (limpa o bit NOXTAL para usar o cristal externo de 25 MHz)
    BIC R0, R0, #SYSCTL_MOSCCTL_PWRDN          ; R0 = R0&~SYSCTL_MOSCCTL_PWRDN (limpa o bit PWRDN para ligar o oscilador principal)
    STR R0, [R1]                               ; [R1] = R0 (ambas alterações em um único acesso)
    ;    Esperar pelo bit MOSCPUPRIS ser setado no registrador SYSCTL_RIS_R register, indicando
	;    que o cristal modo MOSC está pronto
    LDR R1, =SYSCTL_RIS_R                      ; R1 = SYSCTL_RIS_R (pointer)
PLL_Init_step3loop
    LDR R0, [R1]                               ; R0 = [R1] (value)
    ANDS R0, R0, #SYSCTL_RIS_MOSCPUPRIS        ; R0 = R0&SYSCTL_RIS_MOSCPUPRIS
    BEQ PLL_Init_step3loop                     ; if(R0 == 0), keep polling

    ; 4) Setar os campos OSCSRC e PLLSRC para 0x3 no registrador SYSCTL_RSCLKCFG_R
    ;    no offset 0x0B0.
    LDR R1, =SYSCTL_RSCLKCFG_R                 ; R1 = SYSCTL_RSCLKCFG_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_RSCLKCFG_OSCSRC_M      ; R0 = R0&~SYSCTL_RSCLKCFG_OSCSRC_M (limpar o campo system run/sleep clock source)
    ADD R0, R0, #SYSCTL_RSCLKCFG_OSCSRC_MOSC   ; R0 = R0 + SYSCTL_RSCLKCFG_OSCSRC_MOSC (configurar para temporariamente obter o clock do oscilador de 25MHz principal)
    BIC R0, R0, #SYSCTL_RSCLKCFG_PLLSRC_M      ; R0 = R0&~SYSCTL_RSCLKCFG_PLLSRC_M (limpar o campo PLL clock source)
    ADD R0, R0, #SYSCTL_RSCLKCFG_PLLSRC_MOSC   ; R0 = R0 + SYSCTL_RSCLKCFG_PLLSRC_MOSC (configurar para o clock do PLL do oscilador principal)
    STR R0, [R1]                               ; [R1] = R0
    ; 5) Se a aplicação também necessita que o MOSC seja a fonte de clock para deep-sleep
    ;    então programar o campo DSOSCSRC no registrador SYSCTL_DSCLKCFG_R para 0x3.
    LDR R1, =SYSCTL_DSCLKCFG_R                 ; R1 = SYSCTL_DSCLKCFG_R (pointer)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_DSCLKCFG_DSOSCSRC_M    ; R0 = R0&~SYSCTL_DSCLKCFG_DSOSCSRC_M (clear system deep-sleep clock source field)
    ADD R0, R0, #SYSCTL_DSCLKCFG_DSOSCSRC_MOSC ; R0 = R0 + SYSCTL_DSCLKCFG_DSOSCSRC_MOSC (configure to get deep-sleep clock from main oscillator)
    STR R0, [R1]                               ; [R1] = R0
    ; 6) Escrever os registradores SYSCTL_PLLFREQ0_R e SYSCTL_PLLFREQ1_R com os valores de
    ;    Q, N, MINT, e MFRAC para configurar as configurações desejadas da frequência de VCO.
    ;    ************
    ;    fVC0 = (fXTAL/(Q + 1)/(N + 1))*(MINT + (MFRAC/1,024))
    ;    fVCO = 480,000,000 Hz (arbitrary, but presumably as small as needed)
	;    Para uma frequência que não seja um divisor inteiro de 480 MHz, mudar esta seção
FXTAL  EQU 25000000                 ; fixa, o cristal está soldado no Launchpad
Q      EQU        0
N      EQU        4                 ; escolhido para ser a frequência de referência entre 4 e 30 MHz
MINT   EQU       96                 ; 480,000,000 = (25,000,000/(0 + 1)/(4 + 1))*(96 + (0/1,024))
MFRAC  EQU        0                 ; zero para reduzir o jitter
    ;    SysClk = fVCO / (PSYSDIV + 1)
SYSCLK EQU (FXTAL/(Q+1)/(N+1))*(MINT+MFRAC/1024)/(PSYSDIV+1)
    LDR R1, =SYSCTL_PLLFREQ0_R                 ; R1 = SYSCTL_PLLFREQ0_R (ponteiro)
    LDR R0, [R1]                               ; R0 = [R1] (valor)
    LDR R3, =SYSCTL_PLLFREQ0_MFRAC_M           ; R3 = SYSCTL_PLLFREQ0_MFRAC_M (máscar)
    BIC R0, R0, R3                             ; R0 = R0&~SYSCTL_PLLFREQ0_MFRAC_M (limpar o campo MFRAC)
    LDR R3, =(MFRAC<<SYSCTL_PLLFREQ0_MFRAC_S)  ; R3 = (MFRAC<<SYSCTL_PLLFREQ0_MFRAC_S) (valor deslocado)
    ADD R0, R0, R3                             ; R0 = R0 + (MFRAC<<SYSCTL_PLLFREQ0_MFRAC_S) (configurar MFRAC como definido acima)
    LDR R3, =SYSCTL_PLLFREQ0_MINT_M            ; R3 = SYSCTL_PLLFREQ0_MINT_M (máscara)
    BIC R0, R0, R3                             ; R0 = R0&~SYSCTL_PLLFREQ0_MINT_M (limpar o campo MINT)
    ADD R0, R0, #(MINT<<SYSCTL_PLLFREQ0_MINT_S); R0 = R0 + (MINT<<SYSCTL_PLLFREQ0_MINT_S) (configurar MINT como definido acima)
    STR R0, [R1]                               ; [R1] = R0 (MFRAC e MINT alteraram mas não estão fixados ainda)
    LDR R1, =SYSCTL_PLLFREQ1_R                 ; R1 = SYSCTL_PLLFREQ1_R (ponteiro)
    LDR R0, [R1]                               ; R0 = [R1] (value)
    BIC R0, R0, #SYSCTL_PLLFREQ1_Q_M           ; R0 = R0&~SYSCTL_PLLFREQ1_Q_M (limpar o campo Q)
    ADD R0, R0, #(Q<<SYSCTL_PLLFREQ1_Q_S)      ; R0 = R0 + (Q<<SYSCTL_PLLFREQ1_Q_S) (configurar Q como definido acima)
    BIC R0, R0, #SYSCTL_PLLFREQ1_N_M           ; R0 = R0&~SYSCTL_PLLFREQ1_N_M (limpar o campo N)
    ADD R0, R0, #(N<<SYSCTL_PLLFREQ1_N_S)      ; R0 = R0 + (N<<SYSCTL_PLLFREQ1_N_S) (configurar N como definido acima)
    STR R0, [R1]                               ; [R1] = R0 (Q e N alteraram mas não estão fixados ainda)
    LDR R1, =SYSCTL_PLLFREQ0_R                 ; R1 = SYSCTL_PLLFREQ0_R (ponteiro)
    LDR R0, [R1]                               ; R0 = [R1] (valor)
    ORR R0, R0, #SYSCTL_PLLFREQ0_PLLPWR        ; R0 = R0|SYSCTL_PLLFREQ0_PLLPWR (ligar a energia para o PLL)
    STR R0, [R1]                               ; [R1] = R0
    LDR R1, =SYSCTL_RSCLKCFG_R                 ; R1 = SYSCTL_RSCLKCFG_R (ponteiro)
    LDR R0, [R1]                               ; R0 = [R1] (valor)
    ORR R0, R0, #SYSCTL_RSCLKCFG_NEWFREQ       ; R0 = R0|SYSCTL_RSCLKCFG_NEWFREQ (fixar as mudanças no registrador)
    STR R0, [R1]                               ; [R1] = R0
    ; 7) Escrever o registrador SYSCTL_MEMTIM0_R para a nova configuração de clock.
    ;    ************
    ;    Configurar os parâmetros de tempo para as memórias Flash e EEPROM que 
	;    dependem da frequência do clock do sistema. Ver a Tabela 5-12 do datasheet.
    LDR R1, =SYSCTL_MEMTIM0_R                  ; R1 = SYSCTL_MEMTIM0_R (ponteiro)
    LDR R0, [R1]                               ; R0 = [R1] (valor)
    LDR R3, =0x03EF03EF                        ; R3 = 0x03EF03EF (máscara)
    BIC R0, R0, R3                             ; R0 = R0&~0x03EF03EF (limpar os campos EBCHT, EBCE, EWS, FBCHT, FBCE, e FWS fields)
    LDR R2, =SYSCLK                            ; R2 = (FXTAL/(Q+1)/(N+1))*(MINT+MFRAC/1024)/(PSYSDIV+1)
    LDR R3, =120000000                          ; R3 = 80,000,000 (value)
    CMP R2, R3                                 ; é R2 (SysClk) <= R3 (120,000,000 Hz)?
    BLS PLL_Init_step7fullspeed                ; se sim, pular o próximo teste
PLL_Init_step7toofast                          ; 120 MHz < SysClk: "too fast"
    ; Um configuração é inválida e o PLL não pode operar mais rápido que 120MHz.
    ; Pula o resto da inicialização, levando o sistema a operar pelo MOSC
    ; que é o cristal de 25MHz.
    BX  LR                                     ; retorna
PLL_Init_step7fullspeed                        ; 100 MHz < SysClk <= 120 MHz: "full speed"
    LDR R3, =100000000                         ; R3 = 100,000,000 (valor)
    CMP R2, R3                                 ; é R2 (SysClk) <= R3 (100,000,000 Hz)?
    BLS PLL_Init_step7veryfast                 ; se sim, pula o próximo teste
    LDR R3, =0x01850185                        ; R3 = 0x01850185 (valores deslocados)
    ADD R0, R0, R3                             ; R0 = R0 + 0x01850185 (FBCHT/EBCHT = 6, FBCE/EBCE = 0, FWS/EWS = 5)
    B   PLL_Init_step7done                     ; branch incondicional para o fim
PLL_Init_step7veryfast                         ; 80 MHz < SysClk <= 100 MHz: "very fast"
    LDR R3, =80000000                          ; R3 = 80,000,000 (valor)
    CMP R2, R3                                 ; é R2 (SysClk) <= R3 (80,000,000 Hz)?
    BLS PLL_Init_step7fast                     ; se sim, pula o próximo teste
    LDR R3, =0x01440144                        ; R3 = 0x01440144 (valores deslocados)
    ADD R0, R0, R3                             ; R0 = R0 + 0x01440144 (FBCHT/EBCHT = 5, FBCE/EBCE = 0, FWS/EWS = 4)
    B   PLL_Init_step7done                     ; branch incondicional para o fim
PLL_Init_step7fast                             ; 60 MHz < SysClk <= 80 MHz: "fast"
    LDR R3, =60000000                          ; R3 = 60,000,000 (valor)
    CMP R2, R3                                 ; é R2 (SysClk) <= R3 (60,000,000 Hz)?
    BLS PLL_Init_step7medium                   ; se sim, pula o próximo teste
    LDR R3, =0x01030103                        ; R3 = 0x01030103 (valores deslocados)
    ADD R0, R0, R3                             ; R0 = R0 + 0x01030103 (FBCHT/EBCHT = 4, FBCE/EBCE = 0, FWS/EWS = 3)
    B   PLL_Init_step7done                     ; branch incondicional para o fim
PLL_Init_step7medium                           ; 40 MHz < SysClk <= 60 MHz: "medium"
    LDR R3, =40000000                          ; R3 = 40,000,000 (valor)
    CMP R2, R3                                 ; é R2 (SysClk) <= R3 (40,000,000 Hz)?
    BLS PLL_Init_step7slow                     ; se sim, pula o próximo teste
    ADD R0, R0, #0x00C200C2                    ; R0 = R0 + 0x00C200C2 (FBCHT/EBCHT = 3, FBCE/EBCE = 0, FWS/EWS = 2)
    B   PLL_Init_step7done                     ; branch incondicional para o fim
PLL_Init_step7slow                             ; 16 MHz < SysClk <= 40 MHz: "slow"
    LDR R3, =16000000                          ; R3 = 16,000,000 (value)
    CMP R2, R3                                 ; é R2 (SysClk) <= R3 (16,000,000 Hz)?
    BLS PLL_Init_step7veryslow                 ; se sim, pula o próximo teste
    ADD R0, R0, #0x00810081                    ; R0 = R0 + 0x00810081 (FBCHT/EBCHT = 2, FBCE/EBCE = 1, FWS/EWS = 1)
    B   PLL_Init_step7done                     ; branch incondicional para o fim
PLL_Init_step7veryslow                         ; SysClk == 16 MHz: "very slow"
    LDR R3, =16000000                          ; R3 = 16,000,000 (value)
    CMP R2, R3                                 ; é R2 (SysClk) < R3 (16,000,000 Hz)?
    BLO PLL_Init_step7extremelyslow            ; se sim, pula o próximo teste
    ADD R0, R0, #0x00200020                    ; R0 = R0 + 0x00200020 (FBCHT/EBCHT = 0, FBCE/EBCE = 1, FWS/EWS = 0)
    B   PLL_Init_step7done                     ; branch incondicional para o fim
PLL_Init_step7extremelyslow                    ; SysClk < 16 MHz: "extremely slow"
    ADD R0, R0, #0x00000000                    ; R0 = R0 + 0x00000000 (FBCHT/EBCHT = 0, FBCE/EBCE = 0, FWS/EWS = 0)
PLL_Init_step7done
    STR R0, [R1]                               ; [R1] = R0 (SYSCTL_MEMTIM0_R alterado mas não fixado ainda)
    ; 8) Espera pelo registrador SYSCTL_PLLSTAT_R indicar que o PLL atingiu travamento
    ;    no novo ponto de operação (ou que um período de timeout passou e o travamento
    ;    falhou, que no caso uma condição de erro existe e esta sequência é abandonada
    LDR R1, =SYSCTL_PLLSTAT_R                  ; R1 = SYSCTL_PLLSTAT_R (pointer)
    MOV R2, #0                                 ; R2 = 0 (timeout counter)
    MOV R3, #0xFFFF                            ; R3 = 0xFFFF (value)
PLL_Init_step8loop
    LDR R0, [R1]                               ; R0 = [R1] (value)
    ANDS R0, R0, #SYSCTL_PLLSTAT_LOCK          ; R0 = R0&SYSCTL_PLLSTAT_LOCK
    BNE PLL_Init_step8done                     ; se (R0 != 0), terminar polling
    ADD R2, R2, #1                             ; R2 = R2 + 1 (incrementar o contador de timeout)
    CMP R2, R3                                 ; se (R2 < 0xFFFF), continuar o polling
    BLO PLL_Init_step8loop
    ; O PLL nunca travou ou não está ligado.
	; Pular o resto da inicialização, levando o sistema ser clockado pelo MOSC,
	; que é um cristal de 25MHz.
    BX  LR                                     ; return
PLL_Init_step8done
    ; 9)Escrever o valor do PSYSDIV no registrador SYSCTL_RSCLKCFG_R, setar o bit USEPLL para
    ;   ser habilitado e setar o bit MEMTIMU.
    LDR R1, =SYSCTL_RSCLKCFG_R                 ; R1 = SYSCTL_RSCLKCFG_R (ponteiro)
    LDR R0, [R1]                               ; R0 = [R1] (valor)
    LDR R3, =SYSCTL_RSCLKCFG_PSYSDIV_M         ; R3 = SYSCTL_RSCLKCFG_PSYSDIV_M (mascara)
    BIC R0, R0, R3                             ; R0 = R0&~SYSCTL_RSCLKCFG_PSYSDIV_M (limpar o campo PSYSDIV)
    ADD R0, R0, #(PSYSDIV&SYSCTL_RSCLKCFG_PSYSDIV_M); R0 = R0 + (PSYSDIV&SYSCTL_RSCLKCFG_PSYSDIV_M) (configurar PSYSDIV como definido acima)
    ORR R0, R0, #SYSCTL_RSCLKCFG_MEMTIMU       ; R0 = R0|SYSCTL_RSCLKCFG_MEMTIMU (setar o bit MEMTIMU para atualizar os parâmetros de temporização de memória)
    ORR R0, R0, #SYSCTL_RSCLKCFG_USEPLL        ; R0 = R0|SYSCTL_RSCLKCFG_USEPLL (setar o bit USEPLL para pegar o clock do PLL)
    STR R0, [R1]                               ; [R1] = R0 (execução e acesso são suspensas enquanto as atualizações na temporização da memória são atualizadas)
    BX  LR                                     ; return


; -------------------------------------------------------------------------------------------------------------------------
; SYSTICK
; -------------------------------------------------------------------------------------------------------------------------
NVIC_ST_CTRL_R        EQU 0xE000E010
NVIC_ST_RELOAD_R      EQU 0xE000E014
NVIC_ST_CURRENT_R     EQU 0xE000E018
; -------------------------------------------------------------------------------------------------------------------------	
        EXPORT  SysTick_Init
		EXPORT  SysTick_Wait1ms
		EXPORT  SysTick_Wait1us
;------------SysTick_Init------------
; Configura o sistema para utilizar o SysTick para delays
; Entrada: Nenhum
; Saída: Nenhum
; Modifica: R0, R1
SysTick_Init
	LDR R1, =NVIC_ST_CTRL_R			; R1 = &NVIC_ST_CTRL_R (ponteiro)
	MOV R0, #0 						; desabilita Systick durante a configuração
	STR R0, [R1]					; escreve no endereço de memória do periférico
	LDR R1, =NVIC_ST_RELOAD_R 		; R1 = &NVIC_ST_RELOAD_R (pointeiro)
	LDR R0, =0x00FFFFFF; 			; valor máximo de recarga 2^24 ticks
	STR R0, [R1] 					; escreve no endereço de memória do periférico o NVIC_ST_RELOAD_M
	LDR R1, =NVIC_ST_CURRENT_R 		; R1 = &NVIC_ST_CURRENT_R (ponteiro)
	MOV R0, #0 						; qualquer escrita no endereço NVIC_ST_CURRENT_R o limpa
	STR R0, [R1] 					; limpa o contador
	LDR R1, =NVIC_ST_CTRL_R 		; habilita o SysTick com o clock do core
	MOV R0, #0x05					; ENABLE | CLK_SRC
	STR R0, [R1] 					; Seta os bits de ENABLE e CLK_SRC na memória
	BX LR
	
;------------SysTick_Wait------------
; Atraso de tempo utilizando processador ocupado
; Entrada: R0 -> parâmetro de delay em unidades do clock do core (12.5ns)
; Saída: Nenhum
; Modifica: R0
SysTick_Wait
	PUSH {R1, R3}						; Salva os valores de R1 e R3 externos
	LDR R1, =NVIC_ST_RELOAD_R 			; R1 = &NVIC_ST_RELOAD_RSUB R0 (ponteiro)
	SUB R0, #1                          
	STR R0, [R1] 						; delay-1, número de contagens para esperar
	LDR R1, =NVIC_ST_CTRL_R 			; R1 = &NVIC_ST_CTRL_R
SysTick_Wait_loop
	LDR R3, [R1] 						; R3 = &NVIC_ST_CTRL_R (ponteiro)
	ANDS R3, R3, #0x00010000 			; O bit COUNT está setado? (Bit 16)
	BEQ SysTick_Wait_loop               ; Se sim permanece no loop
	POP {R1, R3}						; Restaura
	BX LR                               ; Se não, retorna

;------------SysTick_Wait1ms------------
; tempo de atraso usando processador ocupado. Assume um clock de 80 MHz
; Entrada: R0 --> Número de vezes para contar 1ms.
; Saída: Não tem
; Modifica: R0
DELAY1MS EQU 80000 ; número de ciclos de clock para contar 1ms (assumindo 80 MHz)
	               ; 80000 x 12,5 ns = 1 ms

SysTick_Wait1ms
	PUSH {R4, LR} 						; salva o valor atual de R4 e Link Register
	MOVS R4, R0 						; R4 = R0  numEsperasRestantes com atualização dos flags
	BEQ SysTick_Wait1ms_done 			; Se o numEsperasRestantes == 0, vai para o fim
SysTick_Wait1ms_loop					
	LDR R0, =DELAY1MS 					; R0 = DELAY1MS (número de ticks para contar 1ms)
	BL SysTick_Wait 					; chama a rotina para esperar por 1ms
	SUBS R4, R4, #1 					; R4 = R4 - 1; numEsperasRestantes--
	BHI SysTick_Wait1ms_loop 			; se (numEsperasRestantes > 0), espera mais 1ms
SysTick_Wait1ms_done
	POP {R4, PC}                        ;return
	
;------------SysTick_Wait1us------------
; tempo de atraso usando processador ocupado. Assume um clock de 80 MHz
; Entrada: R0 --> Número de vezes para contar 1ms.
; Saída: Não tem
; Modifica: R0
DELAY1US EQU 80    ; número de ciclos de clock para contar 1us (assumindo 80 MHz)
	               ; 80 x 12,5 ns = 1 us

SysTick_Wait1us
	PUSH {R4, LR} 						; salva o valor atual de R4 e Link Register
	MOVS R4, R0 						; R4 = R0  numEsperasRestantes com atualização dos flags
	BEQ SysTick_Wait1us_done 			; Se o numEsperasRestantes == 0, vai para o fim
SysTick_Wait1us_loop					
	LDR R0, =DELAY1US 					; R0 = DELAY1US (número de ticks para contar 1us)
	BL SysTick_Wait 					; chama a rotina para esperar por 1us
	SUBS R4, R4, #1 					; R4 = R4 - 1; numEsperasRestantes--
	BHI SysTick_Wait1us_loop 			; se (numEsperasRestantes > 0), espera mais 1us
SysTick_Wait1us_done
	POP {R4, PC}                        ;return	
	

; -------------------------------------------------------------------------------------------------------------------------
; Fim do Arquivo
; -------------------------------------------------------------------------------------------------------------------------
    ALIGN                        ;Garante que o fim da seção está alinhada 
    END                          ;Fim do arquivo
