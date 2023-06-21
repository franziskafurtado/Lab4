#include <stdint.h>
#include "tm4c1294ncpdt.h"

#define GPIO_PORTA  (0x1) //bit 1
#define GPIO_PORTE  (0x10) //bit 5
#define GPIO_PORTF  (0x20) //bit 6


void timer_init(void);
void SysTick_Wait1ms(uint32_t delay);

extern char velocidade, comando;
extern uint8_t sentido;
uint32_t potIter;

void GPIO_Init(void){
		uint32_t aux;
	
		//Configura UART
		//Inicia clock UART0
		SYSCTL_RCGCUART_R = 0x1;
		
		while((SYSCTL_PRUART_R & 0x1) != 0x1){}
			
		UART0_CTL_R = UART0_CTL_R & 0xFFFFFFFE;
			
		UART0_IBRD_R = 520;
		UART0_FBRD_R = 0;
			
		UART0_LCRH_R = (0x3 << 5)|(0x1<<4);
		UART0_CC_R = 0x0;
			
		UART0_CTL_R = (0x1 << 9)|(0x1 << 8)|0x1;
			
			
		//Configura GPIO	
		SYSCTL_RCGCGPIO_R = SYSCTL_RCGCGPIO_R | GPIO_PORTA | GPIO_PORTF | GPIO_PORTE;
			
		while((SYSCTL_RCGCGPIO_R & (GPIO_PORTA|GPIO_PORTF|GPIO_PORTE) )!=(GPIO_PORTA|GPIO_PORTF|GPIO_PORTE)){}
			
		//GPIO UART
		GPIO_PORTA_AHB_AMSEL_R = 0x00;
			
		aux = GPIO_PORTA_AHB_PCTL_R & 0xFFFFFF00;
		GPIO_PORTA_AHB_PCTL_R = aux | 0x11;
			
		aux = GPIO_PORTA_AHB_AFSEL_R & 0xFFFFFF00;
		GPIO_PORTA_AHB_AFSEL_R = aux | 0x3;
			
		aux = GPIO_PORTA_AHB_DEN_R & 0xFFFFFF00;
		GPIO_PORTA_AHB_DEN_R = aux | 0x3;
			
		//GPIO Motor
		// 2. Limpar o AMSEL para desabilitar a analógica
		GPIO_PORTF_AHB_AMSEL_R = 0x00;
		
		// 3. Limpar PCTL para selecionar o GPIO
		GPIO_PORTF_AHB_PCTL_R = 0x00;

		// 4. DIR para 0 se for entrada, 1 se for saída
		GPIO_PORTF_AHB_DIR_R = 0x04; //BIT2
			
		// 5. Limpar os bits AFSEL para 0 para selecionar GPIO sem função alternativa	
		GPIO_PORTF_AHB_AFSEL_R = 0x00; 
		
		// 6. Setar os bits de DEN para habilitar I/O digital	
		GPIO_PORTF_AHB_DEN_R = 0x04; 		   //Bit2

		//Enable do motor
		GPIO_PORTF_AHB_DATA_R = 0x4;

		//GPIO Potenciometro e Motor
		GPIO_PORTE_AHB_AMSEL_R = 0x10;
		
		GPIO_PORTE_AHB_PCTL_R = 0x00;

		GPIO_PORTE_AHB_DIR_R = 0x03;
		
		GPIO_PORTE_AHB_AFSEL_R = 0x10; 
		
		GPIO_PORTE_AHB_DEN_R = 0x03;
		
		//Configura ADC
		SYSCTL_RCGCADC_R = 0x1;
		while((SYSCTL_PRADC_R&0x1) != 0x1){}
		ADC0_PC_R = 0x7;
			
		aux = ADC0_SSPRI_R & 0xFFFFCCCC;
		ADC0_SSPRI_R = aux | 0x00000123;
		ADC0_ACTSS_R = ADC0_ACTSS_R & 0xFFFFFFF0;
		ADC0_EMUX_R = ADC0_EMUX_R & 0xFFFF0FFF;
		ADC0_SSMUX3_R = 9;
		ADC0_SSCTL3_R = 0x6;
		ADC0_ACTSS_R = ADC0_ACTSS_R | 0x8;

}

void timer_init(void){
	uint32_t aux;
	SYSCTL_RCGCTIMER_R = SYSCTL_RCGCTIMER_R | 0x4;
	while((SYSCTL_RCGCTIMER_R & 0x4) != 0x4 ){}
	TIMER2_CTL_R = TIMER2_CTL_R & 0xfffffffe;
	TIMER2_CFG_R = 0x00;
	aux = TIMER2_TAMR_R & 0xfffffffc;
	TIMER2_TAMR_R = aux | 0x01;
	TIMER2_TAILR_R = 80000;
	TIMER2_TAPR_R = 0x00;
	TIMER2_ICR_R = TIMER2_ICR_R | 0x1;
	TIMER2_IMR_R = TIMER2_IMR_R | 0x1;
	NVIC_PRI5_R = 4 << 29;
	NVIC_EN0_R = 1 << 23;
	TIMER2_CTL_R = TIMER2_CTL_R | 0x1;
		
	potIter = 0;
}

char leUART(void){
	//espera fila ter alguma coisa
	while(UART0_FR_R & (0x1 << 4)){}
		
	return((uint8_t)UART0_DR_R&0xFF);
}

void escreveUART(char* c){
	uint32_t i;
	
	for(i=0;c[i]!='\0';i++){
		while(UART0_FR_R & (0x1 << 5)){}
		UART0_DR_R = c[i];
	}
}

uint32_t lePot(void){
	uint32_t ret;
	ADC0_PSSI_R = 0x0008;
	while((ADC0_RIS_R&0x8) != 0x8){}
	ret = ADC0_SSFIFO3_R;
	ADC0_ISC_R = 0x8;
	return(ret);
}

void Timer2A_Handler(void){
	float vel;
	char charAux[] = "x\0";
	uint32_t aux;
	TIMER2_ICR_R = 0x1;
	
		vel = (float)(((float)lePot()*10.0)/4096.0);
		potIter++;
		if(potIter%2000==0){
			potIter = 0;
			aux = (uint32_t) (vel*10);
			if(aux==100){
				escreveUART("100\0");
			
			}
			else{
				charAux[0] = (aux/10)+48;
				escreveUART(charAux);
				charAux[0] = (aux%10)+48;
				escreveUART(charAux);
			}
			escreveUART("%\r\n\0");
		}
	
	
	if(!vel){
		TIMER2_TAILR_R = 80000;
		GPIO_PORTE_AHB_DATA_R = GPIO_PORTE_AHB_DATA_R & 0xFFFFFFFC;
	}
	else{
		if(GPIO_PORTE_AHB_DATA_R&0x3){ //Se motor ligado
			TIMER2_TAILR_R = (uint32_t)(10.0-vel)*8000.0;
			GPIO_PORTE_AHB_DATA_R = GPIO_PORTE_AHB_DATA_R & 0xFFFFFFFC;
		}
		else{
			TIMER2_TAILR_R = (uint32_t)vel*8000.0;
			aux = GPIO_PORTE_AHB_DATA_R & 0xFFFFFFFC;
			if(sentido=='h'){
				GPIO_PORTE_AHB_DATA_R = aux | 0x1;
			}
			else{
				GPIO_PORTE_AHB_DATA_R = aux | 0x2;
			}
		}
	}
	TIMER2_CTL_R = TIMER2_CTL_R | 0x1;
}
