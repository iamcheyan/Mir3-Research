# Microsoft Developer Studio Project File - Name="_Oranze Library" - Package Owner=<4>
# Microsoft Developer Studio Generated Build File, Format Version 6.00
# ** DO NOT EDIT **

# TARGTYPE "Win32 (x86) Static Library" 0x0104

CFG=_Oranze Library - Win32 Debug
!MESSAGE This is not a valid makefile. To build this project using NMAKE,
!MESSAGE use the Export Makefile command and run
!MESSAGE 
!MESSAGE NMAKE /f "_Oranze Library.mak".
!MESSAGE 
!MESSAGE You can specify a configuration when running NMAKE
!MESSAGE by defining the macro CFG on the command line. For example:
!MESSAGE 
!MESSAGE NMAKE /f "_Oranze Library.mak" CFG="_Oranze Library - Win32 Debug"
!MESSAGE 
!MESSAGE Possible choices for configuration are:
!MESSAGE 
!MESSAGE "_Oranze Library - Win32 Release" (based on "Win32 (x86) Static Library")
!MESSAGE "_Oranze Library - Win32 Debug" (based on "Win32 (x86) Static Library")
!MESSAGE 

# Begin Project
# PROP AllowPerConfigDependencies 0
# PROP Scc_ProjName ""
# PROP Scc_LocalPath ""
CPP=cl.exe
RSC=rc.exe

!IF  "$(CFG)" == "_Oranze Library - Win32 Release"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 0
# PROP BASE Output_Dir "Release"
# PROP BASE Intermediate_Dir "Release"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 0
# PROP Output_Dir "_Bin"
# PROP Intermediate_Dir "_Obj_Release"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD CPP /nologo /MT /W3 /GX /O2 /D "WIN32" /D "NDEBUG" /D "_MBCS" /D "_LIB" /YX /FD /c
# ADD BASE RSC /l 0x412 /d "NDEBUG"
# ADD RSC /l 0x412 /d "NDEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo

!ELSEIF  "$(CFG)" == "_Oranze Library - Win32 Debug"

# PROP BASE Use_MFC 0
# PROP BASE Use_Debug_Libraries 1
# PROP BASE Output_Dir "Debug"
# PROP BASE Intermediate_Dir "Debug"
# PROP BASE Target_Dir ""
# PROP Use_MFC 0
# PROP Use_Debug_Libraries 1
# PROP Output_Dir "_Bin"
# PROP Intermediate_Dir "_Obj_Debug"
# PROP Target_Dir ""
# ADD BASE CPP /nologo /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /GZ /c
# ADD CPP /nologo /MTd /W3 /Gm /GX /ZI /Od /D "WIN32" /D "_DEBUG" /D "_MBCS" /D "_LIB" /YX /FD /GZ /c
# ADD BASE RSC /l 0x412 /d "_DEBUG"
# ADD RSC /l 0x412 /d "_DEBUG"
BSC32=bscmake.exe
# ADD BASE BSC32 /nologo
# ADD BSC32 /nologo
LIB32=link.exe -lib
# ADD BASE LIB32 /nologo
# ADD LIB32 /nologo /out:"_Bin\_Oranze Library_Debug.lib"

!ENDIF 

# Begin Target

# Name "_Oranze Library - Win32 Release"
# Name "_Oranze Library - Win32 Debug"
# Begin Group "Source Files"

# PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# Begin Source File

SOURCE=.\base64.cpp
# End Source File
# Begin Source File

SOURCE=.\database.cpp
# End Source File
# Begin Source File

SOURCE=.\datelog.cpp
# End Source File
# Begin Source File

SOURCE=.\error.cpp
# End Source File
# Begin Source File

SOURCE=.\file.cpp
# End Source File
# Begin Source File

SOURCE=.\http.cpp
# End Source File
# Begin Source File

SOURCE=.\imsgfmt.cpp
# End Source File
# Begin Source File

SOURCE=.\mail.cpp
# End Source File
# Begin Source File

SOURCE=.\mime.cpp
# End Source File
# Begin Source File

SOURCE=.\netbase.cpp
# End Source File
# Begin Source File

SOURCE=.\netiocp.cpp
# End Source File
# Begin Source File

SOURCE=.\nettcp.cpp
# End Source File
# Begin Source File

SOURCE=.\netudp.cpp
# End Source File
# Begin Source File

SOURCE=.\pop3.cpp
# End Source File
# Begin Source File

SOURCE=.\prime.cpp
# End Source File
# Begin Source File

SOURCE=.\quotedpr.cpp
# End Source File
# Begin Source File

SOURCE=.\registry.cpp
# End Source File
# Begin Source File

SOURCE=.\script.cpp
# End Source File
# Begin Source File

SOURCE=.\stringex.cpp
# End Source File
# Begin Source File

SOURCE=.\syncobj.cpp
# End Source File
# Begin Source File

SOURCE=.\url.cpp
# End Source File
# Begin Source File

SOURCE=.\util.cpp
# End Source File
# Begin Source File

SOURCE=.\uucp.cpp
# End Source File
# End Group
# Begin Group "Header Files"

# PROP Default_Filter "h;hpp;hxx;hm;inl"
# Begin Source File

SOURCE=.\astar.h
# End Source File
# Begin Source File

SOURCE=.\base64.h
# End Source File
# Begin Source File

SOURCE=.\bstree.h
# End Source File
# Begin Source File

SOURCE=.\database.h
# End Source File
# Begin Source File

SOURCE=.\datatype.h
# End Source File
# Begin Source File

SOURCE=.\datelog.h
# End Source File
# Begin Source File

SOURCE=.\error.h
# End Source File
# Begin Source File

SOURCE=.\file.h
# End Source File
# Begin Source File

SOURCE=.\fsa.h
# End Source File
# Begin Source File

SOURCE=.\http.h
# End Source File
# Begin Source File

SOURCE=.\imsgfmt.h
# End Source File
# Begin Source File

SOURCE=.\indexmap.h
# End Source File
# Begin Source File

SOURCE=.\list.h
# End Source File
# Begin Source File

SOURCE=.\mail.h
# End Source File
# Begin Source File

SOURCE=.\map.h
# End Source File
# Begin Source File

SOURCE=.\mime.h
# End Source File
# Begin Source File

SOURCE=.\netbase.h
# End Source File
# Begin Source File

SOURCE=.\netiocp.h
# End Source File
# Begin Source File

SOURCE=.\nettcp.h
# End Source File
# Begin Source File

SOURCE=.\netudp.h
# End Source File
# Begin Source File

SOURCE=.\pop3.h
# End Source File
# Begin Source File

SOURCE=.\pqueue.h
# End Source File
# Begin Source File

SOURCE=.\prime.h
# End Source File
# Begin Source File

SOURCE=.\queue.h
# End Source File
# Begin Source File

SOURCE=.\quotedpr.h
# End Source File
# Begin Source File

SOURCE=.\registry.h
# End Source File
# Begin Source File

SOURCE=.\script.h
# End Source File
# Begin Source File

SOURCE=.\slist.h
# End Source File
# Begin Source File

SOURCE=.\stack.h
# End Source File
# Begin Source File

SOURCE=.\streambf.h
# End Source File
# Begin Source File

SOURCE=.\stringex.h
# End Source File
# Begin Source File

SOURCE=.\syncobj.h
# End Source File
# Begin Source File

SOURCE=.\url.h
# End Source File
# Begin Source File

SOURCE=.\util.h
# End Source File
# Begin Source File

SOURCE=.\uucp.h
# End Source File
# Begin Source File

SOURCE=.\vector.h
# End Source File
# End Group
# End Target
# End Project
