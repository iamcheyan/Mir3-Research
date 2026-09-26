

/*
	Queue

	Date:
		2001/04/10
*/
#ifndef __ORZ_DATASTRUCTURE_SYNC_QUEUE__
#define __ORZ_DATASTRUCTURE_SYNC_QUEUE__


#include "syncobj.h"
#include "Queue.h"


template< class T >
class CSQueue : public CQueue< T >, public CIntLock
{
};


#endif