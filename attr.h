/**********************************************
        CS515  Project 2
        Fall  2018
        Student Version
**********************************************/

#ifndef ATTR_H
#define ATTR_H

typedef union {int num; char *str;} tokentype;

typedef enum {
	TYPE_INT
} Type;

typedef enum{
	QUANTITY_SCALAR, QUANTITY_ARRAY
} Quantity;

typedef struct{
	int precondition;
	int success;
	int failure;
	int postcondition;
	int successRegister;
} JumpControl;

typedef struct{
	int countOffset;
	int lowBound;
	int highBound;
} CntrlExpr;

typedef struct {
        int targetRegister;
        } regInfo;

typedef struct VariableList{
	char** names;
	int numNames;
} VariableList;

typedef struct{
	Type type;
	Quantity quantity;
	int numQuantity;
} VarType;

int getOffset(int numQuantity);
int nextLabel();

#endif


  
