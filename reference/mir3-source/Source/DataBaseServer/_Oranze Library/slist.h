

/*
	List

	Date:
		2001/04/10
*/
#ifndef __ORZ_DATASTRUCTURE_SYNC_LIST__
#define __ORZ_DATASTRUCTURE_SYNC_LIST__


#include "syncobj.h"
#include "list.h"


template< class T >
class CSList : public CList< T >, public CIntLock
{
};


#endif