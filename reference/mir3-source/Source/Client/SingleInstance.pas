{
   SingleInstance 뮤텍스를 이용한 하나의 인스탄스만을 실행되도록 고정
}
unit SingleInstance;

interface

uses
  Windows;
  
type
  TSingleInstance = class
  protected
     m_hMutex : HWND;
     m_strClassName : string;     //char [256];
  public
     constructor Create;
     destructor Destroy;
     function Initialize( strID : string ) : Boolean;
  end;

implementation

constructor TSingleInstance.Create;
begin
   // Set our default values
   m_hMutex := 0;
end;

destructor TSingleInstance.Destroy;
begin
   if ( m_hMutex <> 0 ) then begin
      ReleaseMutex( m_hMutex );
      CloseHandle( m_hMutex );
      m_hMutex := 0;
   end;
end;

function  TSingleInstance.Initialize( strID : string ) : boolean;
var
   hndWnd : HWND;
begin
    m_strClassName := strID + ' Class';
    m_hMutex       := CreateMutex( nil, FALSE, PChar(m_strClassName) );
    // Check for errors

    if ( GetLastError() = ERROR_ALREADY_EXISTS ) then begin

        // Reset our mutext handle (just in case)
        m_hMutex := 0;
{
        // The mutex already exists, which means an instance is already
        // running. Find the app and pop it up
        hndWnd := FindWindowEx( NULL, NULL, PChar(strID), nil );
        if ( hndWnd <> 0 ) then begin
            ShowWindow( hndWnd, SW_RESTORE );
            BringWindowToTop( hndWnd );
            SetForegroundWindow( hndWnd );
        end;
        // Return failure
}
        Result := FALSE;
    end else
        Result := TRUE;
end;

end.
