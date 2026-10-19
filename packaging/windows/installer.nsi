; Windows installer for Video Trimmer, built with NSIS.
; makensis -DVERSION=0.1.0 -DDIST=path\to\video-trimmer -DOUTFILE=setup.exe installer.nsi

Unicode true
!include "MUI2.nsh"

!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!ifndef DIST
  !define DIST "..\..\dist\video-trimmer"
!endif
!ifndef OUTFILE
  !define OUTFILE "video-trimmer-${VERSION}-setup.exe"
!endif

!define APP "Video Trimmer"
!define EXE "video-trimmer.exe"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\VideoTrimmer"

Name "${APP}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\${APP}"
InstallDirRegKey HKLM "Software\VideoTrimmer" "InstallDir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APP}"
VIAddVersionKey "FileDescription" "${APP} installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Video Trimmer contributors"

!define MUI_ICON "..\icons\video-trimmer.ico"
!define MUI_UNICON "..\icons\video-trimmer.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

; The installer and uninstaller replace the whole install folder, so only
; allow a new or empty folder, or one that already holds this app.
Function .onVerifyInstDir
  IfFileExists "$INSTDIR\${EXE}" ok
  FindFirst $0 $1 "$INSTDIR\*.*"
  loop:
    StrCmp $1 "" done
    StrCmp $1 "." next
    StrCmp $1 ".." next
    FindClose $0
    Abort ; holds other files
  next:
    FindNext $0 $1
    Goto loop
  done:
  FindClose $0
  ok:
FunctionEnd

Section "Video Trimmer (required)" SecApp
  SectionIn RO
  ; Clear out an older version's files first, so no stale DLLs are left behind.
  IfFileExists "$INSTDIR\${EXE}" 0 +2
    RMDir /r "$INSTDIR"
  SetOutPath "$INSTDIR"
  File /r "${DIST}\*.*"
  WriteUninstaller "$INSTDIR\uninstall.exe"

  CreateShortcut "$SMPROGRAMS\${APP}.lnk" "$INSTDIR\${EXE}"

  WriteRegStr HKLM "Software\VideoTrimmer" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${APP}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${EXE}"
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\${EXE}"
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\${APP}.lnk"
  Delete "$DESKTOP\${APP}.lnk"
  IfFileExists "$INSTDIR\${EXE}" 0 +2
    RMDir /r "$INSTDIR"
  DeleteRegKey HKLM "${UNINST_KEY}"
  DeleteRegKey HKLM "Software\VideoTrimmer"
SectionEnd
