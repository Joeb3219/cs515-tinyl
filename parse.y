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

%union {tokentype token;
		regInfo targetReg;
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
	| VAR vardcls { }
	;

vardcls	: vardcls vardcl ';' { }
	| vardcl ';' { }
	| error ';' { yyerror("***Error: illegal variable declaration\n");}  
	;

vardcl	: idlist ':' type {  }
	;

idlist	: idlist ',' ID { insert($3.str, NextOffset(1)); } /* BOGUS  - needs to be fixed */
		| ID		{ insert($1.str, NextOffset(1)); } /* BOGUS  - needs to be fixed */
	;

type	: ARRAY '[' ICONST ']' OF INT {  }

		| INT {  }
	;

stmtlist : stmtlist ';' stmt { }
	| stmt { }
		| error { yyerror("***Error: ';' expected or illegal statement \n");}
	;

stmt    : ifstmt { }
	| fstmt { }
	| astmt { }
	| writestmt { }
	| cmpdstmt { }
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

fstmt	: FOR ctrlexp DO stmt  {  } 
	;


astmt : lhs ASG exp             { 
				  emit(NOLABEL,
									   STORE, 
									   $3.targetRegister,
									   $1.targetRegister,
									   EMPTY);
								}
	;

lhs	: ID			{ /* BOGUS  - needs to be fixed */
								  int newReg1 = NextRegister();
								  int newReg2 = NextRegister();
								  int offset = NextOffset(4);
				  
								  $$.targetRegister = newReg2;

				  emit(NOLABEL, LOADI, offset, newReg1, EMPTY);
				  emit(NOLABEL, ADD, 0, newReg1, newReg2);
				  
							  }


								|  ID '[' exp ']' {   }
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



exp	: exp '+' exp		{ int newReg = NextRegister();

								  $$.targetRegister = newReg;
								  emit(NOLABEL, 
									   ADD, 
									   $1.targetRegister, 
									   $3.targetRegister, 
									   newReg);
								}

		| exp '-' exp		{  }

		| exp '*' exp		{  }


		| ID			{ /* BOGUS  - needs to be fixed */
							  int newReg = NextRegister();
								  int offset = NextOffset(4);

							  $$.targetRegister = newReg;
				  emit(NOLABEL, LOADAI, 0, offset, newReg);
								  
							}

		| ID '[' exp ']'	{   }
 


	| ICONST                 { int newReg = NextRegister();
							   $$.targetRegister = newReg;
				   emit(NOLABEL, LOADI, $1.num, newReg, EMPTY); }

	| error { yyerror("***Error: illegal expression\n");}  
	;

ctrlexp	: ID ASG ICONST ',' ICONST {  }
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




