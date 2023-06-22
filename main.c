#include <stdint.h>

void PLL_Init(void);
void SysTick_Init(void);
void SysTick_Wait1ms(uint32_t delay);
void GPIO_Init(void);
void timer_init(void);

char leUART(void);
void escreveUART(char* c);

char comando;
uint8_t sentido;
uint8_t changed;

int main(void){
	char charAux[] = "x\0";
	PLL_Init();
	SysTick_Init();
	GPIO_Init();

	changed = 0;
	
	leUART();
	escreveUART("\n\0");
	escreveUART("Lab 4\r\n\0");  
	escreveUART("\n\0");

	escreveUART("MOTOR PARADO\r\n\0");
	escreveUART("Insira o sentido de rotacao: h -> horario, a -> anti-horario\r\n\0");

		
	do{
		sentido = leUART();
	}while(!(sentido=='a'||sentido=='h'));
	
	if(sentido=='h'){
		escreveUART("\r\nSentido horario\r\n\0");
	}
	else{
		escreveUART("\r\nSentido anti-horario\r\n\0");
	}	

	timer_init();
	
	while(1){
			comando = leUART();
			if(comando=='h'||comando=='a'){
			sentido = comando;
			changed = 1;
			if(sentido=='h'){
				escreveUART("\r\nSentido horario\r\n\0");
			}
			else{
				escreveUART("\r\nSentido anti-horario\r\n\0");
			}	
		}
	}
}
