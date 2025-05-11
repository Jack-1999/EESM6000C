#include "fir.h"

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//initial your fir
	for (int i = 0; i < N; i++){
		inputbuffer[i] = 0;
		outputsignal[i] = 0;
	}
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	initfir();
	//write down your fir
	int out_data;
	for (int i = 0; i < N; i++){
		out_data = 0;
		inputbuffer[i] = inputsignal[i];
		for (int j = 0; j < N; j++){
			out_data += outputsignal[i-j] * taps[j];
		}
		outputsignal[i] = out_data;
	}
	return outputsignal;
}
		
