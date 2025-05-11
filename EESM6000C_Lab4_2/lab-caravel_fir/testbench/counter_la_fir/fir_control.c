#include "fir.h"

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//initial your fir
	reg_fir_data_length = data_length;
	reg_fir_tap_num = N;
	for (int i = 0;i < N; i++){
		reg_fir_coeff(i) = taps[i];
	}
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	initfir();
	//write down your fir
	reg_fir_control = 1;
	for (int i = 0;i < data_length; i++){
		reg_fir_x[i] = i;
		outputsignal[i] = reg_fir_y;
	}		
	return outputsignal;
}
		
