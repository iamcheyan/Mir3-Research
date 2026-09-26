

/*
	Fixed Size Allocator

	Date:
		2002/03/05

	Note:
		메모리 할당/해제에 드는 비용(Cost)과 단편화(Fragmentation)를 줄이기 위한 클래스
*/
#ifndef __ORZ_MEMORY_ALLOCATOR__
#define __ORZ_MEMORY_ALLOCATOR__


template< class T >
class CFixedSizeAllocator
{
public:
	class CMemBlock
	{
	public:
		T			tData;
		CMemBlock	*pNext;
	};

protected:
	CMemBlock *	m_pMemory;
	CMemBlock * m_pFirstFree;
	int			m_nCapacity;

public:
	CFixedSizeAllocator();
	CFixedSizeAllocator( int nCapacity );
	virtual ~CFixedSizeAllocator();

	bool Init( int nCapacity );
	void Uninit();

	T *  Alloc();
	void Free( T *pMemory );

protected:
	void ConstructFreeList( int nFrom, int nTo );
};


template< class T >
CFixedSizeAllocator< T >::CFixedSizeAllocator()
{
	m_pMemory		= NULL;
	m_pFirstFree	= NULL;
	m_nCapacity		= 0;
}


template< class T >
CFixedSizeAllocator< T >::CFixedSizeAllocator( int nCapacity )
{
	Init( nCapacity );
}


template< class T >
CFixedSizeAllocator< T >::~CFixedSizeAllocator()
{
	Uninit();
}


template< class T >
bool CFixedSizeAllocator< T >::Init( int nCapacity )
{
	m_pMemory		= NULL;
	m_pFirstFree	= NULL;
	m_nCapacity		= 0;

	m_pMemory = new CMemBlock[ nCapacity ];
	if ( !m_pMemory )
		return false;

	ConstructFreeList( 0, m_nCapacity );

	return true;
}


template< class T >
void CFixedSizeAllocator< T >::Uninit()
{
	if ( m_pMemory )
	{
		delete[] m_pMemory;
		m_pMemory = NULL;
	}

	m_pFirstFree = NULL;
	m_nCapacity	 = 0;
}


template< class T >
T * CFixedSizeAllocator< T >::Alloc()
{
	if ( !m_pFirstFree )
		return NULL;
	
	CMemBlock *pBlock	= m_pFirstFree;
	m_pFirstFree		= pBlock->pNext;

	return (T *) pBlock;
}


template< class T >
void CFixedSizeAllocator< T >::Free( T *pMemory )
{
	CMemBlock *pBlock = (CMemBlock *) pMemory;

	pBlock->pNext = m_pFirstFree;
	m_pFirstFree  = pBlock;
}


template< class T >
void CFixedSizeAllocator< T >::ConstructFreeList( int nFrom, int nTo )
{
	CMemBlock *pBaseMemory	= &m_pMemory[nFrom];
	m_pFirstFree			= pBaseMemory;

	for ( int i = nFrom + 1; i < nTo; i++ )
	{
		pBaseMemory->pNext = pBaseMemory + 1;
		pBaseMemory++;
	}

	pBaseMemory->pNext = NULL;
}


#endif