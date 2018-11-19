%{
#include <stdio.h>
#include "attr.h"
#include "instrutil.h"
int yylex();
void yyerror(char * s);
#include "symtab.h"

FILE *outfile;
char *CommentBuffer;
 
%}

%union {
		tokentype token;
		regInfo targetReg;
		VarType varType;
		VariableList variableList;
		JumpControl jumpControl;
		CntrlExpr cntrlExpr;
	   }

%token PROG PERIOD VAR 
%token INT BOOL PRINT THEN IF DO  
%token ARRAY OF 
%token BEG END ASG  
%token EQ NEQ LT LEQ 
%token ELSE
%token FOR 
%token <token> ID ICONST 

%type <targetReg> exp 
%type <targetReg> lhs 
%type <varType> type
%type <variableList> idlist
%type <jumpControl> FOR
%type <cntrlExpr> ctrlexp

%start program

%nonassoc EQ NEQ LT LEQ 
%left '+' '-' 
%left '*' 

%nonassoc THEN
%nonassoc ELSE

%%
program : {emitComment("Assign STATIC_AREA_ADDRESS to register \"r0\"");
		   emit(NOLABEL, LOADI, STATIC_AREA_ADDRESS, 0, EMPTY);} 
		   PROG ID ';' block PERIOD { }
	;

block	: variables cmpdstmt { }
	;

variables: /* empty */
	| VAR vardcls {  }
	;

vardcls	: vardcls vardcl ';' { }
	| vardcl ';' { }
	| error ';' { yyerror("***Error: illegal variable declaration\n");}  
	;

vardcl	: idlist ':' type 	{
								int i = 0;
								for(i = 0; i < $1.numNames; i ++){
									char* name = $1.names[i];

									insert(name, $3.type, $3.quantity, getOffset($3.numQuantity));
								}
								free($1.names);
							}
	;

idlist	: idlist ',' ID { 
							$$.numNames	= 1 + $1.numNames;
							$$.names 	= malloc(sizeof(char*) * $$.numNames);
							memcpy($$.names, $1.names, $1.numNames * sizeof(char*));
							$$.names[$$.numNames - 1] = $3.str;
							free($1.names);
						}
		| ID		{ 
						$$.numNames = 1;
						$$.names = malloc(sizeof(char*));
						$$.names[0] = $1.str;
					} 
	;

type	: ARRAY '[' ICONST ']' OF INT { $$.type = TYPE_INT; $$.quantity = $$.quantity = QUANTITY_ARRAY; $$.numQuantity = $3.num; }

		| INT { $$.type = TYPE_INT; $$.quantity = QUANTITY_SCALAR; $$.numQuantity = 1;}
	;

stmtlist : stmtlist ';' stmt { }
	| stmt { }
		| error { yyerror("***Error: ';' expected or illegal statement \n");}
	;

stmt    : ifstmt {
				
				 }

	| fstmt { 

			}

	| astmt { 

			}

	| writestmt { 

				}

	| cmpdstmt 	{

				}
	;

cmpdstmt: BEG stmtlist END { }
	;

ifstmt :  ifhead 
		  THEN stmt 
	  ELSE 
		  stmt 
	;

ifhead : IF condexp {  }
		;

fstmt	: FOR 	{
					$1.precondition = nextLabel();
					$1.success 		= nextLabel();
					$1.failure		= nextLabel();

					sprintf(CommentBuffer, "FOR LOOP labels: %d %d %d\n", $1.precondition, $1.success, $1.failure);
					emitComment(CommentBuffer);
			   	} 

			   	ctrlexp 

			   	{
					
			   		// First, we load the initial state of ctrlexp
			   		sprintf(CommentBuffer, "Loading initial value %d into variable w/ offset %d\n", $3.lowBound, $3.countOffset);
			   		emitComment(CommentBuffer);

			   		// Upper Bound
			   		int highRegister = NextRegister();
			   		emit(NOLABEL, LOADI, $3.highBound, highRegister, EMPTY);

			   		int tempRegister = NextRegister();
			   		// Loads initial low value
			   		emit(NOLABEL, LOADI, $3.lowBound, tempRegister, EMPTY);
			   		// Stores the low value into our given variable
			   		emit(NOLABEL, STOREAI, tempRegister, 0, $3.countOffset);


			   		// Now we can handle the actual precondition nonsense
			   		sprintf(CommentBuffer, "Precondition\n");
			   		emitComment(CommentBuffer);

			   		int testRegister = NextRegister();

			   		// Whether or not we proceed
					int successRegister = NextRegister();

					emit($1.precondition, LOADAI, 0, $3.countOffset, testRegister);
					emit(NOLABEL, CMPLE, testRegister, highRegister, successRegister);

			   		emit(NOLABEL, CBR, successRegister, $1.success, $1.failure);

			   		sprintf(CommentBuffer, "FOR LOOP @ %d body: %d\n", $1.precondition, $1.success);
			   		emitComment(CommentBuffer);

			   		emit($1.success, NOP, EMPTY, EMPTY, EMPTY);

			   	}

			   	DO stmt  	{

			   					sprintf(CommentBuffer, "Looping back to top of loop @ %d\n", $1.precondition);
								emitComment(CommentBuffer);

								// Increment the count variable
								int loadCount = NextRegister();
								emit(NOLABEL, LOADAI, 0, $3.countOffset, loadCount);
								emit(NOLABEL, ADDI, loadCount, 1, loadCount);
								emit(NOLABEL, STOREAI, loadCount, 0, $3.countOffset);

								emit(NOLABEL, BR, $1.precondition, EMPTY, EMPTY);

			   					sprintf(CommentBuffer, "We're done otherwise, so we'll drop our failure condiiton.\n");
								emitComment(CommentBuffer);

								emit($1.failure, NOP, EMPTY, EMPTY, EMPTY);


							} 
	;


astmt : lhs ASG exp             { 
				  emit(NOLABEL,
									   STORE, 
									   $3.targetRegister,
									   $1.targetRegister,
									   EMPTY);
								}
	;

lhs	: ID			{
						int offset;

						SymTabEntry *varEntry = lookup($1.str);

						if(varEntry == NULL){
							printf("Unknown variable %s\n.", $1.str);
							return -1;
						}else if(varEntry->quantity != QUANTITY_SCALAR){
							printf("Variable isn't a scalar: %s\n", $1.str);
							return -1;
						}

						offset = varEntry->offset;

						int addressRegister = NextRegister(); // We need to load in the offset and add it to the base register
						$$.targetRegister = NextRegister();
						
						sprintf(CommentBuffer, "Loading variable %s (offset %d) into reg %d", $1.str, offset, $$.targetRegister);
						emitComment(CommentBuffer);

						emit(NOLABEL, LOADI, offset, addressRegister, EMPTY);
						emit(NOLABEL, ADD, 0, addressRegister, $$.targetRegister);
					}


	|  ID '[' exp ']' 	{

						}
								;

writestmt: PRINT '(' exp ')' { int printOffset = -4; /* default location for printing */
							 sprintf(CommentBuffer, "Code for \"PRINT\" from offset %d", printOffset);
							 emitComment(CommentBuffer);
								 emit(NOLABEL, STOREAI, $3.targetRegister, 0, printOffset);
								 emit(NOLABEL, 
									  OUTPUTAI, 
									  0,
									  printOffset, 
									  EMPTY);
							   }
	;



exp	: exp '+' exp		{ 


								int newReg = NextRegister();
								  $$.targetRegister = newReg;
								  emit(NOLABEL, 
									   ADD, 
									   $1.targetRegister, 
									   $3.targetRegister, 
									   newReg);
						}

		| exp '-' exp		{

								int newReg = NextRegister();
								  $$.targetRegister = newReg;
								  emit(NOLABEL, 
									   SUB, 
									   $1.targetRegister, 
									   $3.targetRegister, 
									   newReg);

		}

		| exp '*' exp		{ 

								int newReg = NextRegister();
								  $$.targetRegister = newReg;
								  emit(NOLABEL, 
									   MULT, 
									   $1.targetRegister, 
									   $3.targetRegister, 
									   newReg);

							}


		| ID			{ 
							int offset;

							SymTabEntry *varEntry = lookup($1.str);

							if(varEntry == NULL){
								printf("Unknown variable %s\n.", $1.str);
								return -1;
							}else if(varEntry->quantity != QUANTITY_SCALAR){
								printf("Variable isn't a scalar: %s\n", $1.str);
								return -1;
							}

							offset = varEntry->offset;

							$$.targetRegister = NextRegister();
							
							sprintf(CommentBuffer, "Loading variable %s (offset %d) from rhs into reg %d", $1.str, offset, $$.targetRegister);
							emitComment(CommentBuffer);

							emit(NOLABEL, LOADAI, 0, offset, $$.targetRegister);
						}

		| ID '[' exp ']'	{   }
 


	| ICONST                 { int newReg = NextRegister();
							   $$.targetRegister = newReg;
				   emit(NOLABEL, LOADI, $1.num, newReg, EMPTY); }

	| error { yyerror("***Error: illegal expression\n");}  
	;

ctrlexp	: ID ASG ICONST ',' ICONST 	{ 

										$$.lowBound 		= $3.num;
										$$.highBound 		= $5.num;
										
										SymTabEntry *varEntry = lookup($1.str);

										if(varEntry == NULL){
											printf("Unknown variable %s\n.", $1.str);
											return -1;
										}else if(varEntry->quantity != QUANTITY_SCALAR){
											printf("Variable isn't a scalar: %s\n", $1.str);
											return -1;
										}

										$$.countOffset = varEntry->offset;

									}
	| error { yyerror("***Error: illegal control expression\n");}  
		;


condexp	: exp NEQ exp		{  } 

		| exp EQ exp		{  } 

		| exp LT exp		{  }

		| exp LEQ exp		{  }

	| error { yyerror("***Error: illegal conditional expression\n");}  
		;

%%

void yyerror(char* s) {
		fprintf(stderr,"%s\n",s);
		}


int
main(int argc, char* argv[]) {

  printf("\n     CS515 Fall 2018 Compiler\n\n");

  outfile = fopen("iloc.out", "w");
  if (outfile == NULL) { 
	printf("ERROR: cannot open output file \"iloc.out\".\n");
	return -1;
  }

  CommentBuffer = (char *) malloc(650);  
  InitSymbolTable();

  printf("1\t");
  yyparse();
  printf("\n");

  PrintSymbolTable();
  
  fclose(outfile);
  
  return 1;
}




