/*
------------------------------------------------------------------------------
Standard definitions and types, Bob Jenkins
------------------------------------------------------------------------------

Modified a bit for Success::Token

*/


#ifndef STANDARD
# define STANDARD

// Support both ILP32 and LP64
typedef unsigned int ub4;
typedef int word;

#define bis(target,mask)  ((target) |=  (mask))
#define bic(target,mask)  ((target) &= ~(mask))
#define bit(target,mask)  ((target) &   (mask))
#ifndef min
# define min(a,b) (((a)<(b)) ? (a) : (b))
#endif /* min */
#ifndef max
# define max(a,b) (((a)<(b)) ? (b) : (a))
#endif /* max */
#ifndef align
# define align(a) (((ub4)a+(sizeof(void *)-1))&(~(sizeof(void *)-1)))
#endif /* align */
#ifndef abs
# define abs(a)   (((a)>0) ? (a) : -(a))
#endif

#ifndef TRUE
# define TRUE  1
#endif

#ifndef FALSE
# define FALSE 0
#endif

#endif /* STANDARD */
