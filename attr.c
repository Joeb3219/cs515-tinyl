/**********************************************
        CS515  Project 2
        Fall  2018
        Student Version
**********************************************/

#include <stdlib.h>
#include <stdio.h>
#include "attr.h" 

int currentOffset = 0;
int currentLabel = 0;

int nextLabel(){
	return currentLabel ++;
}

int getOffset(int numQuantity){
	int returnVal = currentOffset;

	currentOffset += (numQuantity * 4);

	return returnVal;
}