

#include "vtimage.h"
#include <stdio.h>
#include <math.h>


typedef bool (CVtImage:: *extFunc)( char *fname );

static struct VTI_FILEEXT
{
	char	ext[4];
	extFunc	open;
	extFunc save;
} g_extList[] = 
{
	"BIF",	CVtImage::OpenBif,	CVtImage::SaveBif,
	"BMP",	CVtImage::OpenBmp,	CVtImage::SaveBmp,
	"GIF",	CVtImage::OpenGif,	CVtImage::SaveGif,
	"JPG",	CVtImage::OpenJpg,	CVtImage::SaveJpg,
	"PCX",	CVtImage::OpenPcx,	CVtImage::SavePcx,
	"PNG",	CVtImage::OpenPng,	CVtImage::SavePng,
	"TGA",	CVtImage::OpenTga,	CVtImage::SaveTga,
};

static int g_extCnt = sizeof( g_extList ) / sizeof( g_extList[0] );


CVtImage::CVtImage()
{
	m_hPal		= NULL;
	m_nErrCode	= BAD_OPN;
}


CVtImage::~CVtImage()
{
	if ( m_hPal )
		DeleteObject( m_hPal );
}


bool CVtImage::Open( char *fname )
{
	__try
	{
		char *ext = strrchr( fname, '.' ) + 1;

		for ( int i = 0; i < g_extCnt; i++ )
		{
			if ( stricmp( ext, g_extList[i].ext ) == 0 )
				return ( this->*g_extList[i].open )( fname );
		}
	}
	__except ( EXCEPTION_EXECUTE_HANDLER )
	{
		// memory exception occured.
		m_nErrCode = VTI_MEMORY_EXCEPTION;
		return false;
	}

	// it is not supporting file extension.
	m_nErrCode = VTI_NOT_SUPPORT;
	return false;
}


bool CVtImage::OpenBif( char *fname )
{
	FILE *fp = fopen( fname, "rb" );
	if ( !fp )
		return false;

	fclose( fp );

	return (m_nErrCode = loadbif( fname, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::OpenBmp( char *fname )
{
	BITMAPINFOHEADER dat;

	if ( (m_nErrCode = bmpinfo( fname, &dat )) != NO_ERROR )
		return false;

	// 16/24/32bit file into a 24bit buffer
	if ( dat.biBitCount >= 16 )
		dat.biBitCount = 24;

	if ( (m_nErrCode = ResizeImgBuf( dat.biWidth, dat.biHeight, dat.biBitCount )) != NO_ERROR )
		return false;

	return (m_nErrCode = loadbmp( fname, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::OpenGif( char *fname )
{
	GifData dat;

	if ( (m_nErrCode = gifinfo( fname, &dat )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = ResizeImgBuf( dat.width, dat.length, dat.vbitcount )) != NO_ERROR )
		return false;

	return (m_nErrCode = loadgif( fname, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::OpenJpg( char *fname )
{
	JpegData dat;

	if ( (m_nErrCode = jpeginfo( fname, &dat )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = ResizeImgBuf( dat.width, dat.length, dat.vbitcount )) != NO_ERROR )
		return false;

	return (m_nErrCode = loadjpg( fname, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::OpenPcx( char *fname )
{
	PcxData dat;

	if ( (m_nErrCode = pcxinfo( fname, &dat )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = ResizeImgBuf( dat.width, dat.length, dat.vbitcount )) != NO_ERROR )
		return false;

	return (m_nErrCode = loadpcx( fname, &m_imgdes )) == NO_ERROR;	
}


bool CVtImage::OpenPng( char *fname )
{
	PngData dat;

	if ( (m_nErrCode = pnginfo( fname, &dat )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = ResizeImgBuf( dat.width, dat.length, dat.vbitcount )) != NO_ERROR )
		return false;

	return (m_nErrCode = loadpng( fname, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::OpenTga( char *fname )
{
	TgaData dat;

	if ( (m_nErrCode = tgainfo( fname, &dat )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = ResizeImgBuf( dat.width, dat.length, dat.vbitcount )) != NO_ERROR )
		return false;

	return (m_nErrCode = loadtga( fname, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Save( char *fname )
{
	__try
	{
		char *ext = strrchr( fname, '.' ) + 1;

		for ( int i = 0; i < g_extCnt; i++ )
		{
			if ( stricmp( ext, g_extList[i].ext ) == 0 )
				return ( this->*g_extList[i].save )( fname );
		}
	}
	__except ( EXCEPTION_EXECUTE_HANDLER )
	{
		m_nErrCode = VTI_MEMORY_EXCEPTION;
		return false;
	}

	m_nErrCode = VTI_NOT_SUPPORT;
	return false;
}


bool CVtImage::SaveBif( char *fname )
{
	return (m_nErrCode = savebif( fname, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::SaveBmp( char *fname )
{
	return SaveBmp( fname, false );
}


/*
	SaveBmp()

	comp		: compression type (0 = none, 1: RLE8)
*/
bool CVtImage::SaveBmp( char *fname, bool comp )
{
	return (m_nErrCode = savebmp( fname, &m_imgdes, comp )) == NO_ERROR;
}


bool CVtImage::SaveGif( char *fname )
{
	return SaveGif( fname, GIFLZWCOMP );
}


/*
	SaveGif()

	comp		: compression type 
				  (GIFLZCOMP, GIFINTERLACE, GIFTRANSPARENT, GIFWRITE4BIT, GIFNOCOMP)
	trans_color	: transparent color (0-255)
*/
bool CVtImage::SaveGif( char *fname, int comp, int trans_color )
{
	return (m_nErrCode = savegifex( fname, &m_imgdes, comp, trans_color )) == NO_ERROR;
}


bool CVtImage::SaveJpg( char *fname )
{
	return SaveJpg( fname, 75 );
}


/*
	SaveJpg()

	quality		: image quality (1-100)
*/
bool CVtImage::SaveJpg( char *fname, int quality )
{
	return (m_nErrCode = savejpg( fname, &m_imgdes, quality )) == NO_ERROR;
}


bool CVtImage::SavePcx( char *fname )
{
	return (m_nErrCode = savepcx( fname, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::SavePng( char *fname )
{
	return SavePng( fname, PNGALLFILTERS );
}


/*
	SavePng()

	comp		: compression type
				  (PNGALLFILTERS, PNGNOFILTER, PNGSUBFILTER, PNGUPFILTER, PNGAVGFILTER, PNGPAETHFILTER)
*/
bool CVtImage::SavePng( char *fname, int comp )
{
	return (m_nErrCode = savepng( fname, &m_imgdes, comp )) == NO_ERROR;
}


bool CVtImage::SaveTga( char *fname )
{
	return SaveTga( fname, false );
}


/*
	SaveTga()
	
	comp		: compression type (0 = none, 1: RLE)
*/
bool CVtImage::SaveTga( char *fname, bool comp )
{
	return (m_nErrCode = savetga( fname, &m_imgdes, comp )) == NO_ERROR;
}


int CVtImage::Width()
{
	return m_imgdes.bmh->biWidth;
}


int CVtImage::Height()
{
	return m_imgdes.bmh->biHeight;
}


int CVtImage::Bpp()
{
	return m_imgdes.bmh->biBitCount;
}


void CVtImage::AreaToRect( RECT *rc )
{
	imageareatorect( &m_imgdes, rc );
}


void CVtImage::RectToArea( RECT *rc )
{
	recttoimagearea( rc, &m_imgdes );
}


void CVtImage::SetArea( int sx, int sy, int ex, int ey )
{
	setimagearea( &m_imgdes, sx, sy, ex, ey );
}


void CVtImage::SetArea( RECT *rc )
{
	setimagearea( &m_imgdes, rc->left, rc->top, rc->right, rc->bottom );
}


void CVtImage::ResetArea()
{
	setimagearea( &m_imgdes, 0, 0, Width() - 1, Height() - 1 );
}


bool CVtImage::Flip()
{
	return (m_nErrCode = flipimage( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Mirror()
{
	return (m_nErrCode = mirrorimage( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Rotate( double angle )
{
	imgdes timage;

	int dx, dy;
	CalcMinRotImageArea( angle, &dx, &dy );

	// whole region rotate
	if ( m_imgdes.stx  == 0 && 
		 m_imgdes.sty  == 0 && 
		 m_imgdes.endx == (unsigned) Width() - 1 && 
		 m_imgdes.endy == (unsigned) Height() - 1 )
	{
		if ( (m_nErrCode = allocimage( &timage, dx, dy, Bpp() )) != NO_ERROR )
			return false;
		zeroimage( 0, &timage );

		if ( (m_nErrCode = rotate( angle, &m_imgdes, &timage )) != NO_ERROR )
		{
			freeimage( &timage );
			return false;
		}

		copyimagepalette( &m_imgdes, &timage );
		freeimage( &m_imgdes );
		copyimgdes( &timage, &m_imgdes );
	}
	// specified region rotate
	else
	{
		copyimgdes( &m_imgdes, &timage );
		timage.endx = timage.stx + dx - 1;
		timage.endy = timage.sty + dy - 1;

		// clip the resulting rotated image, if necessary
		if ( timage.endx > (unsigned) timage.bmh->biWidth - 1 )
			timage.endx = timage.bmh->biWidth - 1;
		if ( timage.endy > (unsigned) timage.bmh->biHeight - 1 )
			timage.endy = timage.bmh->biHeight - 1;

		if ( (m_nErrCode = rotate( angle, &m_imgdes, &timage )) == NO_ERROR )
		{
			m_imgdes.endx = timage.endx;
			m_imgdes.endy = timage.endy;
		}
	}

	return true;
}


bool CVtImage::Resize( int width, int height )
{
	imgdes timage;

	if ( (m_nErrCode = allocimage( &timage, width, height, Bpp() )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = resizeex( &m_imgdes, &timage, RESIZEBILINEAR )) != NO_ERROR )
	{
		freeimage( &timage );
		return false;
	}

	freeimage( &m_imgdes );
	copyimgdes( &timage, &m_imgdes );

	return true;
}


bool CVtImage::Resize( int percent )
{
	int dx = (int)(((long)(m_imgdes.endx - m_imgdes.stx + 1) * percent) / 100);
	int dy = (int)(((long)(m_imgdes.endy - m_imgdes.sty + 1) * percent) / 100);

	return Resize( dx, dy );
}
 

bool CVtImage::Crop()
{
	return Resize( 100 );
}


bool CVtImage::Equalize()
{
	return (m_nErrCode = histoequalize( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::HistoBrighten()
{
	return (m_nErrCode = histobrighten( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::ExpandContrast( int min, int max )
{
	return (m_nErrCode = expandcontrast( min, max, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::ChangeBright( int amount )
{
	return (m_nErrCode = changebright( amount, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Multiply( int multiplier )
{
	return (m_nErrCode = multiply( multiplier, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Divide( int divisor ) 
{
	return (m_nErrCode = divide( divisor, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Negative()
{
	return (m_nErrCode = negative( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Kodalith( int threshold )
{
	return (m_nErrCode = kodalith( threshold, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::GammaBrighten( double factor )
{
	return (m_nErrCode = gammabrighten( factor, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::GentlySharpen()
{
	return (m_nErrCode = sharpengentle( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Sharpen()
{
	return (m_nErrCode = sharpen( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Outline()
{
	return (m_nErrCode = outline( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Trace()
{
	int red, grn, blu;
	return ((m_nErrCode = calcavglevel( &m_imgdes, &red, &grn, &blu )) == NO_ERROR && Kodalith( red ) && Outline());
}


bool CVtImage::RemoveNoise()
{
	return (m_nErrCode = removenoise( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Blur()
{
	return (m_nErrCode = blur( &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Pixellize( int factor )
{
	return (m_nErrCode = pixellize( factor, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Posterize( int levels )
{
	unsigned char table[256];
	for ( int i = 0; i < 256; i++ )
		table[i] = (unsigned char)((i / levels) * levels);

	return (m_nErrCode = usetable( table, table, table, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Erode( int amount )
{
	return (m_nErrCode = erode( amount, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::Dilate( int amount )
{
	return (m_nErrCode = dilate( amount, &m_imgdes, &m_imgdes )) == NO_ERROR;
}


bool CVtImage::GrayScale()
{
	ResetArea();

	if ( Bpp() == 8 )
	{
		if ( (m_nErrCode = colortogray( &m_imgdes, &m_imgdes )) != NO_ERROR )
			return false;
	}
	else
	{
		imgdes timage;
		
		if ( (m_nErrCode = allocimage( &timage, Width(), Height(), 8 )) != NO_ERROR )
			return false;

		if ( (m_nErrCode = colortogray( &m_imgdes, &timage )) != NO_ERROR )
		{
			freeimage( &timage );
			return false;
		}

		freeimage( &m_imgdes );
		copyimgdes( &timage, &m_imgdes );
	}

	return true;
}


bool CVtImage::RgbToPal()
{
	ResetArea();

	imgdes timage;

	if ( (m_nErrCode = allocimage( &timage, Width(), Height(), 8 )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = convertrgbtopalex( 256, &m_imgdes, &timage, CR_TSDNODIFF )) != NO_ERROR )
	{
		freeimage( &timage );
		return false;
	}

	freeimage( &m_imgdes );
	copyimgdes( &timage, &m_imgdes );

	return true;
}


bool CVtImage::PalToRgb()
{
	ResetArea();

	imgdes timage;

	if ( (m_nErrCode = allocimage( &timage, Width(), Height(), 24 )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = convertpaltorgb( &m_imgdes, &timage )) != NO_ERROR )
	{
		freeimage( &timage );
		return false;
	}

	freeimage( &m_imgdes );
	copyimgdes( &timage, &m_imgdes );

	return true;
}


bool CVtImage::RgbToPal( char *fname )
{
	CVtImage pal;
	if ( pal.Open( fname ) == false )
		return false;

	imgdes timage;

	if ( (m_nErrCode = allocimage( &timage, Width(), Height(), 8 )) != NO_ERROR )
		return false;

	copyimagepalette( &pal.m_imgdes, &timage );

	if ( (m_nErrCode = matchcolorimage( &m_imgdes, &timage )) != NO_ERROR )
	{
		freeimage( &timage );
		return false;
	}

	freeimage( &m_imgdes );
	copyimgdes( &timage, &m_imgdes );

	return true;	
}


#define VSCATTER 0
#define VDITHER  1
#define VTHRESH  2


bool CVtImage::Convert8to1()
{
	ResetArea();

	imgdes timage;

	if ( (m_nErrCode = allocimage( &timage, Width(), Height(), 1 )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = convert8bitto1bit( VSCATTER, &m_imgdes, &timage )) != NO_ERROR )
	{
		freeimage( &timage );
		return false;
	}

	freeimage( &m_imgdes );
	copyimgdes( &timage, &m_imgdes );

	return true;
}


bool CVtImage::Convert1to8()
{
	ResetArea();

	imgdes timage;

	if ( (m_nErrCode = allocimage( &timage, Width(), Height(), 8 )) != NO_ERROR )
		return false;

	if ( (m_nErrCode = convert1bitto8bit( &m_imgdes, &timage )) != NO_ERROR )
	{
		freeimage( &timage );
		return false;
	}

	freeimage( &m_imgdes );
	copyimgdes( &timage, &m_imgdes );

	return true;
}


bool CVtImage::RealizePalette( HDC dc )
{
	HPALETTE oldPal = SelectPalette( dc, m_hPal, 0 );

	if ( !RealizePalette( dc ) )
	{
		SelectPalette( dc, oldPal, 0 );
		return false;
	}

	UpdateColors( dc );

	SelectPalette( dc, oldPal, 0 );
	return true;
}


/*
	Draw()

	xpos, ypos		: starting position in image to display
	scrnx, scrny	: position in window to display image
*/
bool CVtImage::Draw( HWND wnd, HDC dc, int xpos, int ypos, int scrnx, int scrny )
{
	if ( m_hPal )
	{
		DeleteObject( m_hPal );
		m_hPal = NULL;
	}

	if ( (m_nErrCode = viewimageex( wnd, dc, &m_hPal, xpos, ypos, &m_imgdes, scrnx, scrny, VIEWOPTPAL )) != NO_ERROR )
		return false;

	return true;
}


int CVtImage::ResizeImgBuf( int width, int height, int bpp )
{
	freeimage( &m_imgdes );

	width  = max( width, VTI_MINDIM );
	height = max( height, VTI_MINDIM );

	return allocimage( &m_imgdes, width, height, bpp );
}


#define L_MULTIP 15 // Power of 2 to scale doubles to
#define MRD_FACTOR (double)(1L << L_MULTIP)
#define MRL_FACTOR (1L << L_MULTIP)

#define MRSCALE_UPD(dval) ((long)((dval) * MRD_FACTOR))
#define MRSCALE_DNL(lval) ((int)((lval + (MRL_FACTOR - 1)) / MRL_FACTOR))
#define PI 3.141592654
#define DEGTORAD(ang) ((ang) * PI / 180.0)


void CVtImage::CalcMinRotImageArea( double angle, int *dx, int *dy )
{
	double angRad;

	while ( angle > 360.0 )
		angle -= 360.0;
	while ( angle < -360.0 )
		angle += 360.0;

	// convert angle to radians
	angRad = DEGTORAD( angle );

	int sintheta = MRSCALE_UPD( sin(angRad) );
	int costheta = MRSCALE_UPD( cos(angRad) );
	
	if ( sintheta < 0 )
		sintheta = -sintheta;
	if ( costheta < 0 )
		costheta = -costheta;

	int cols = m_imgdes.endx - m_imgdes.stx + 1;
	int rows = m_imgdes.endy - m_imgdes.sty + 1;

	*dx = MRSCALE_DNL( costheta * cols + sintheta * rows );
	*dy = MRSCALE_DNL( sintheta * cols + costheta * rows );
}


static struct VTI_ERRMSG
{
	int  code;
	char msg[256];
} g_errMsg[] = 
{
	NO_ERROR,				"No error",
	BAD_RANGE,				"Range error",
	NO_DIG,					"Digitizer board not detected",
	BAD_DSK,				"Disk full,file not written",
	BAD_OPN,				"File not found",
	BAD_FAC,				"Non-dimensional variable out of range",
	BAD_TIFF,				"Unreadable TIF format",
	TIFF_NOPAGE,			"TIF page not found",
	TIFF_MOTYPE,			"Can't append an Intel-type TIF to a Motorola-type TIF",
	BAD_BPS,				"TIF bits per sample not supported",
	BAD_CMP,				"Unreadable compression scheme",
	BAD_CRT,				"Cannot create file",
	BAD_FTPE,				"Unknown file format",
	BAD_DIB,				"Device independent bitmap is compressed",
	VMODE_ERR,				"Invalid video mode",
	BAD_MEM,				"Insufficient memory for function",
	BAD_PIW,				"Not PIW format",
	BAD_PCX,				"Unreadable PCX format",
	BAD_GIF,				"Unreadable GIF format",
	GIF_NOFRAME,			"GIF frame not found",
	PRT_ERR,				"Print error",
	PRT_BUSY,				"Print image() is busy",
	SCAN_ERR,				"Scannererror",
	CM_ERR,					"Conventional memory handle overflow",
	NO_EMM,					"Expanded memory manager not found",
	EMM_ERR,				"Expanded memory manager error",
	NO_XMM,					"Expanded memory manager not found",
	XMM_ERR,				"Expanded memory manager error",
	BAD_TGA,				"Unreadable TGA format",
	BAD_BPP,				"Bits per pixel not supported",
	BAD_BMP,				"Unreadable BMP format",
	BAD_JPEG,				"Unreadable JPEG format",
	TOO_CPLX,				"Image is too complex to complete operation",
	NOT_AVAIL,				"Function not available due to missing module",
	LZW_DISABLED,			"LZW functionality disabled",
	BAD_DATA,				"File contains invalid data",
	BAD_PNG,				"Unreadable PNG format",
	BAD_PNG_CMP,			"PNG compressor error",
	NO_ACK,					"No ACK from digitizer",
	BAD_HANDLE,				"Handle not valid",
	BAD_TN_SIZE,			"Thumbnail size out of range",
	BAD_DIGI_MEM,			"Insufficient digitizer memory for selected mode",
	BAD_DIM,				"Image format does not support width or length > 65535",
	SCAN_UNLOAD,			"paper could not be unloaded from ADF",
	SCAN_LIDUP,				"ADF lid was opened",
	SCAN_NOPAPER,			"ADF bin is empty",
	SCAN_NOADF,				"ADF is not connected",
	SCAN_NOTREADY,			"ADF is connected but not ready",
	COM_ERR,				"Serial data reception error",
	BAD_COM,				"No data from COM port",
	NO_DEV_DATA,			"No data from device",
	TIMEOUT,				"Function timed out",
	TWAIN_FIRST_ERR,		"Could not create Twain parent window",
	TWAIN_LAST_ERR,			"Stop scanning images",
	TWAIN_NOWND,			"Could not create Twainparent window",
	TWAIN_NODSM,			"Could not open Twain Source Manager",
	TWAIN_NODS,				"Could not open Twain Data Source",
	TWAIN_ERR,				"Twain image acquisition error",
	TWAIN_NOMATCH,			"None of the elements in two lists were equal",
	TWAIN_BAD_DATATYPE,		"Data type mismatch",
	TWAIN_SCAN_CANCEL,		"User cancelled scan",
	TWAIN_BUSY,				"Twain function is busy",
	TWAIN_NO_PAPER,			"Auto feeder is empty",
	TWAIN_STOP_SCAN,		"Stop scanning images",
	PNG_ERR_UNK_CRIT_CHK,	"Unknown critical chunk",
	PNG_ERR_TOO_FEW_IDATS,	"Not enough IDATs for image",
	PNG_ERR_INV_IHDR_CHK,	"Invalid IHDRchunk",
	PNG_ERR_INV_BITDEPTH,	"Invalid bit depth in IHDR",
	PNG_ERR_INV_COLORTYPE,	"Invalid color type in IHDR",
	PNG_ERR_INV_BITCOL,		"Invalid color type/bit depth combo in IHDR",
	PNG_ERR_INV_INTERLACE,	"Invalid interlace method in IHDR",
	PNG_ERR_INV_COMP,		"Invalid compression method in IHDR",
	PNG_ERR_INV_FILTER,		"Invalid filter method in IHDR",
	PNG_ERR_IMAGE_SIZE,		"Invalid image size in IHDR",
	PNG_ERR_BAD_CRC,		"Bad CRC value",
	PNG_ERR_TOO_MUCH_DATA,	"Extra data at end of file",
	PNG_ERR_EARLY_EOF,		"Unexpected End Of File",
	PNG_ERR_MEM_ERR,		"Memory error",
	PNG_ERR_DECOMPRESSION,	"Decompression error",
	PNG_ERR_COMPRESSION,	"Compression error",
	PNG_ERR_NO_DISK_SPACE,	"Out of disk space",
	JPG_BAD_PRECISION,		"Sample precision is not 8",
	JPG_BAD_EOF,			"Unexpected End Of File",
	JPG_BAD_RESTART,		"Reset marker could not be found",
	JPG_INVALID_MARKER,		"Invalid marker found in the image data",
	JPG_READ_ERR,			"Error reading data from the file",
	JPG_INVALID_DATA,		"Invalid data found in JPEG file",
	JPG_BAD_COMPINFO,		"Component info out of bounds",
	JPG_BAD_BLOCKNO,		"Block sin an MCU is > 10",
	JPG_BAD_BPPIXEL,		"Bits per sample is not 8",
	JPG_BAD_COMPNO,			"Invalid number of components",
	JPG_BAD_FTYPE,			"File type not SOF0 or SOF1",
	JPG_BAD_EOI,			"Unexpected End Of Image",
	JPG_BAD_JFIF,			"File is not JPEG JFIF",
	JPG_BAD_SCAN_PARAM,		"Bad progressive JPEG scan parameter",
	JPG_BAD_MEM,			"Out of memory",
	JPG_NO_DISK_SPACE,		"Out of disk space",
	TIF_INVALID_DATA,		"Invalid data found in TIF file",
	TIF_READ_ERR,			"Error reading data from the file",
	TIF_BAD_EOF,			"Unexpected End Of File",
	TIF_G4_COMPLEX,			"Trans point arrays not large enough",
	BAD_LOCK,				"Out of memory",
	BAD_IBUF,				"Invalid image buffer address",
	BAD_PTR,				"Pointer does not point at readable/writable memory",
	TIGA_BAD_BPP,			"Bits per pixel of TIGA mode not 8",
	TIGA_BAD_MEM,			"Could not allocate enough GSP memory",
	TIGA_NO_EXT,			"Could not load TIGA extended primitives",
	VTI_MEMORY_EXCEPTION,	"Memory exception error",
	VTI_NOT_SUPPORT,		"Invalid image file",
};

static int g_msgCnt = sizeof( g_errMsg ) / sizeof( g_errMsg[0] );


void CVtImage::OutputErrMsg()
{
	for ( int i = 0; i < g_msgCnt; i++ )
	{
		if ( g_errMsg[i].code == m_nErrCode )
		{
			OutputDebugString( g_errMsg[i].msg );
			OutputDebugString( "\n" );
			break;
		}
	}
}


void CVtImage::ErrMsgBox()
{
	for ( int i = 0; i < g_msgCnt; i++ )
	{
		if ( g_errMsg[i].code == m_nErrCode )
		{
			MessageBox( NULL, g_errMsg[i].msg, "Error", MB_ICONWARNING );
			break;
		}
	}
}


int CVtImage::ErrCode()
{
	return m_nErrCode;
}


char * CVtImage::ErrMsg()
{
	for ( int i = 0; i < g_msgCnt; i++ )
	{
		if ( g_errMsg[i].code == m_nErrCode )
		{
			return g_errMsg[i].msg;
		}
	}

	return NULL;
}


bool CVtImage::IsError()
{
	return m_nErrCode != NO_ERROR;
}

