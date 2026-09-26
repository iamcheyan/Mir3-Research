

/*
	Victor Image Processing Library Wrapper Class

	Date:
		2001/11/23
*/
#ifndef __ORZ_GRAPHIC_VICTOR_IMAGE__
#define __ORZ_GRAPHIC_VICTOR_IMAGE__


#include <windows.h>
#include "_link/victor/vicdefs.h"


#define VTI_MINDIM				16

/*
	error code specifically for CVtImage class
*/
#define VTI_MEMORY_EXCEPTION	-1001
#define VTI_NOT_SUPPORT			-1002


class CVtImage
{
public:
	imgdes		m_imgdes;
	HPALETTE	m_hPal;
	int			m_nErrCode;

public:
	CVtImage();
	virtual ~CVtImage();

	/*
		File I/O
	*/
	bool Open( char *fname );
	bool OpenBif( char *fname );
	bool OpenBmp( char *fname );
	bool OpenGif( char *fname );
	bool OpenJpg( char *fname );
	bool OpenPcx( char *fname );
	bool OpenPng( char *fname );
	bool OpenTga( char *fname );

	bool Save( char *fname );
	bool SaveBif( char *fname );
	bool SaveBmp( char *fname );
	bool SaveBmp( char *fname, bool comp );
	bool SaveGif( char *fname );
	bool SaveGif( char *fname, int  comp, int trans_color = 0 );
	bool SaveJpg( char *fname );
	bool SaveJpg( char *fname, int  quality );
	bool SavePcx( char *fname );
	bool SavePng( char *fname );
	bool SavePng( char *fname, int  comp );
	bool SaveTga( char *fname );
	bool SaveTga( char *fname, bool comp );

	/*
		Image Descriptor Informations
	*/
	int  Width();
	int  Height();
	int  Bpp();

	/*
		Helper Functions
	*/
	void AreaToRect( RECT *rc );
	void RectToArea( RECT *rc );

	/*
		Editing
	*/
	void SetArea( int sx, int sy, int ex, int ey );
	void SetArea( RECT *rc );
	void ResetArea();
	bool Flip();
	bool Mirror();
	bool Rotate( double angle );
	bool Resize( int width, int height );
	bool Resize( int percent );
	bool Crop();

	/*
		Bright
	*/
	bool Equalize();
	bool HistoBrighten();
	bool ExpandContrast( int min, int max );	//    0 to 255
	bool ChangeBright( int amount );			// -255 to 255
	bool Multiply( int multiplier );			//    0 to 255
	bool Divide( int divisor ) ;				//    1 to 32767
	bool Negative();
	bool Kodalith( int threshold );				//    0 to 255
	bool GammaBrighten( double factor );		//  0.0 to 1.0 (but it allow any factors)

	/*
		Special Effect
	*/
	bool GentlySharpen();
	bool Sharpen();
	bool Outline();
	bool Trace();
	bool RemoveNoise();
	bool Blur();
	bool Pixellize( int factor );				//    2 to 63
	bool Posterize( int levels );				//    0 to 255
	bool Erode( int amount );					//    0 to 255
	bool Dilate( int amount );					//    0 to 255

	/*
		Convert
	*/
	bool GrayScale();				// color to gray scale
	bool RgbToPal();				// RGB to palette
	bool RgbToPal( char *fname );	// RGB to palette (use an existing palette)
	bool PalToRgb();				// palette to RGB
	bool Convert8to1();				// convert 8bit image to 1bit image
	bool Convert1to8();				// convert 1bit image to 8bit image

	/*
		Output to DC
	*/
	bool RealizePalette( HDC dc );
	bool Draw( HWND wnd, HDC dc, int xpos = 0, int ypos = 0, int scrnx = 0, int scrny = 0 );

protected:
	int  ResizeImgBuf( int width, int height, int bpp );
	void CalcMinRotImageArea( double angle, int *dx, int *dy );

public:
	/*
		Retrieve Error Message
	*/
	void	OutputErrMsg();		// use OutputDebugString()
	void	ErrMsgBox();		// use MessageBox()
	int		ErrCode();
	char *	ErrMsg();
	bool	IsError();
};


#endif