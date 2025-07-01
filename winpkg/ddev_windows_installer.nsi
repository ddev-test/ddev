!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "WinMessages.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"
!include "x64.nsh"
!include "WordFunc.nsh"

!insertmacro WordFind
; Remove the Trim macro since we're using our own TrimWhitespace function

!ifndef TARGET_ARCH # passed on command-line
  !error "TARGET_ARCH define is missing!"
!endif

Name "DDEV Windows Installer"
OutFile "..\.gotmp\bin\windows_${TARGET_ARCH}\ddev_windows_${TARGET_ARCH}_installer.exe"

; Use proper Program Files directory for 64-bit applications
InstallDir "$PROGRAMFILES64\DDEV"
RequestExecutionLevel admin

!define PRODUCT_NAME "DDEV"
!define PRODUCT_VERSION "${VERSION}"
!define PRODUCT_PUBLISHER "DDEV Foundation"

; Variables
Var /GLOBAL INSTALL_OPTION
Var /GLOBAL SELECTED_DISTRO
Var StartMenuGroup

!define REG_INSTDIR_ROOT "HKLM"
!define REG_INSTDIR_KEY "Software\Microsoft\Windows\CurrentVersion\App Paths\ddev.exe"
!define REG_UNINST_ROOT "HKLM"
!define REG_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

; Installer Types
InstType "Full"
InstType "Simple"
InstType "Minimal"

!define MUI_ICON "graphics\ddev-install.ico"
!define MUI_UNICON "graphics\ddev-uninstall.ico"

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "graphics\ddev-header.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "graphics\ddev-wizard.bmp"

!define MUI_ABORTWARNING

; Function declarations - must be before page definitions
Function DistroSelectionPage
    DetailPrint "Starting DistroSelectionPage..."
    ${If} $INSTALL_OPTION != "wsl2-docker-ce"
    ${AndIf} $INSTALL_OPTION != "wsl2-docker-desktop"
        DetailPrint "Skipping distro selection for non-WSL2 install"
        Abort
    ${EndIf}

    DetailPrint "Creating dialog..."
    nsDialogs::Create 1018
    Pop $0
    DetailPrint "Dialog create result: $0"
    ${If} $0 == error
        DetailPrint "Failed to create dialog"
        Abort
    ${EndIf}

    ; Get Ubuntu distros before creating any controls
    Call GetUbuntuDistros
    Pop $R0
    DetailPrint "Got distros: [$R0]"
    ${If} $R0 == ""
        MessageBox MB_ICONSTOP|MB_OK "No Ubuntu-based WSL2 distributions found. Please install Ubuntu for WSL2 first."
        Abort
    ${EndIf}

    DetailPrint "Creating label..."
    ${NSD_CreateLabel} 0 0 100% 24u "Select your Ubuntu-based WSL2 distribution:"
    Pop $1

    DetailPrint "Creating dropdown..."
    ${NSD_CreateDropList} 10 30u 280u 82u ""
    Pop $2

    DetailPrint "Resetting dropdown content..."
    SendMessage $2 ${CB_RESETCONTENT} 0 0

    DetailPrint "Starting to populate dropdown with: [$R0]"

    ; Process the pipe-separated list
    StrCpy $R1 $R0    ; Working copy of the list
    StrCpy $R2 0      ; Item count

    ${Do}
        ; Find position of next pipe or end
        StrCpy $R3 1   ; Length to extract
        StrCpy $R4 0   ; Position
        ${Do}
            StrCpy $R5 $R1 1 $R4  ; Get character at position
            ${If} $R5 == "|"
            ${OrIf} $R5 == ""
                ${Break}
            ${EndIf}
            IntOp $R4 $R4 + 1
        ${Loop}

        ; Extract the item
        ${If} $R4 > 0
            StrCpy $R6 $R1 $R4    ; Extract item
            DetailPrint "Adding item: [$R6]"
            SendMessage $2 ${CB_ADDSTRING} 0 "STR:$R6"
            IntOp $R2 $R2 + 1
        ${EndIf}

        ; Move past the separator
        IntOp $R4 $R4 + 1
        StrCpy $R1 $R1 "" $R4

        ; Check if we're done
        ${If} $R1 == ""
            ${Break}
        ${EndIf}
    ${Loop}

    DetailPrint "Added $R2 items to dropdown"

    ; Select first item if we added any
    ${If} $R2 > 0
        SendMessage $2 ${CB_SETCURSEL} 0 0
    ${EndIf}

    DetailPrint "About to show dialog..."
    nsDialogs::Show
FunctionEnd

Function DistroSelectionPageLeave
    DetailPrint "Getting selected distro..."
    ${NSD_GetText} $2 $SELECTED_DISTRO
    DetailPrint "Selected distro: $SELECTED_DISTRO"
FunctionEnd

; Define pages
!insertmacro MUI_PAGE_WELCOME

; License page for DDEV
!define MUI_PAGE_CUSTOMFUNCTION_PRE ddevLicPre
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE ddevLicLeave
!insertmacro MUI_PAGE_LICENSE "..\LICENSE"

; Custom install type selection
Page custom InstallChoicePage InstallChoicePageLeave

; Add WSL2 distro selection page
Page custom DistroSelectionPage DistroSelectionPageLeave

; Directory page
!define MUI_PAGE_CUSTOMFUNCTION_PRE DirectoryPre
!insertmacro MUI_PAGE_DIRECTORY

; Start menu page
!define MUI_STARTMENUPAGE_DEFAULTFOLDER "${PRODUCT_NAME}"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT ${REG_UNINST_ROOT}
!define MUI_STARTMENUPAGE_REGISTRY_KEY "${REG_UNINST_KEY}"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "StartMenuGroup"
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuGroup

; Installation page
!insertmacro MUI_PAGE_INSTFILES

; Finish page
!define MUI_FINISHPAGE_SHOWREADME "https://github.com/ddev/ddev/releases/tag/${VERSION}"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Review the release notes"
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language - must come after pages
!insertmacro MUI_LANGUAGE "English"

Function InstallChoicePage
    nsDialogs::Create 1018
    Pop $0
    ${If} $0 == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 0 100% 36u "Choose your DDEV installation type:"
    Pop $1

    ${NSD_CreateRadioButton} 10 40u 98% 24u "WSL2 with Docker CE (Recommended)$\nInstalls Docker CE inside WSL2 for best performance"
    Pop $2

    ${NSD_CreateRadioButton} 10 70u 98% 24u "WSL2 with Docker Desktop or Rancher Desktop$\nUse Windows-installed Docker Desktop or Rancher Desktop with WSL2 backend"
    Pop $3

    ${NSD_CreateRadioButton} 10 100u 98% 24u "Traditional Windows$\nClassic Windows installation without WSL2 (Requires Docker Desktop or Rancher Desktop)"
    Pop $4

    ${NSD_SetState} $2 ${BST_CHECKED}
    nsDialogs::Show
FunctionEnd

Function InstallChoicePageLeave
  ${NSD_GetState} $2 $0
  StrCmp $0 ${BST_CHECKED} 0 +2
    StrCpy $INSTALL_OPTION "wsl2-docker-ce"

  ${NSD_GetState} $3 $0
  StrCmp $0 ${BST_CHECKED} 0 +2
    StrCpy $INSTALL_OPTION "wsl2-docker-desktop"

  ${NSD_GetState} $4 $0
  StrCmp $0 ${BST_CHECKED} 0 +2
    StrCpy $INSTALL_OPTION "traditional"
FunctionEnd

Section "-Initialize"
    ; Create the installation directory
    CreateDirectory "$INSTDIR"
SectionEnd

SectionGroup /e "${PRODUCT_NAME}"
    Section "${PRODUCT_NAME}" SecDDEV
        SectionIn 1 2 3 RO

        SetOutPath "$INSTDIR"
        SetOverwrite on

        ; Install ddev-hostname.exe & mkcert.exe for all installation types
        File "..\.gotmp\bin\windows_${TARGET_ARCH}\ddev-hostname.exe"
        File "..\.gotmp\bin\windows_${TARGET_ARCH}\mkcert.exe"
        File "..\.gotmp\bin\windows_${TARGET_ARCH}\mkcert_license.txt"
        File /oname=license.txt "..\LICENSE"

        ; Install icons
        SetOutPath "$INSTDIR\Icons"
        SetOverwrite try
        File /oname=ddev.ico "graphics\ddev-install.ico"

        ${If} $INSTALL_OPTION == "traditional"
            Call InstallTraditionalWindows
        ${Else}
            ${If} $INSTALL_OPTION == "wsl2-docker-ce"
                Call InstallWSL2DockerCE
            ${Else}
                Call InstallWSL2DockerDesktop
            ${EndIf}
        ${EndIf}

        ; Create common shortcuts
        !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
        CreateDirectory "$SMPROGRAMS\$StartMenuGroup"
        CreateShortCut "$SMPROGRAMS\$StartMenuGroup\DDEV.lnk" "$INSTDIR\ddev.exe" "" "$INSTDIR\Icons\ddev.ico"
        !insertmacro MUI_STARTMENU_WRITE_END
    SectionEnd

    Section "Add to PATH" SecAddToPath
        SectionIn 1 2 3
        ; Only add to PATH if not already present
        ReadRegStr $R0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "Path"
        Push $R0
        Push "$INSTDIR"
        Call StrContains
        Pop $R1
        ${If} $R1 == ""
            EnVar::SetHKLM
            EnVar::AddValue "Path" "$INSTDIR"
        ${EndIf}
    SectionEnd
SectionGroupEnd

Section -Post
    WriteUninstaller "$INSTDIR\ddev_uninstall.exe"

    ; Remember install directory for updates
    WriteRegStr ${REG_INSTDIR_ROOT} "${REG_INSTDIR_KEY}" "" "$INSTDIR\ddev.exe"
    WriteRegStr ${REG_INSTDIR_ROOT} "${REG_INSTDIR_KEY}" "Path" "$INSTDIR"

    ; Write uninstaller keys
    WriteRegStr ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "DisplayName" "$(^Name)"
    WriteRegStr ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "UninstallString" "$INSTDIR\ddev_uninstall.exe"
    WriteRegStr ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "DisplayIcon" "$INSTDIR\Icons\ddev.ico"
    WriteRegStr ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
    WriteRegStr ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
    WriteRegDWORD ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "NoModify" 1
    WriteRegDWORD ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "NoRepair" 1

    !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    CreateShortCut "$SMPROGRAMS\$StartMenuGroup\Uninstall ${PRODUCT_NAME}.lnk" "$INSTDIR\ddev_uninstall.exe"
    !insertmacro MUI_STARTMENU_WRITE_END
SectionEnd

Section Uninstall
    ; Remove install directory from system PATH
    EnVar::SetHKLM
    EnVar::DeleteValue "Path" "$INSTDIR"

    ; Remove all installed files
    Delete "$INSTDIR\ddev.exe"
    Delete "$INSTDIR\ddev-hostname.exe"
    Delete "$INSTDIR\mkcert.exe"
    Delete "$INSTDIR\mkcert_license.txt"
    Delete "$INSTDIR\license.txt"
    Delete "$INSTDIR\mkcert install.lnk"
    Delete "$INSTDIR\mkcert uninstall.lnk"
    Delete "$INSTDIR\ddev_uninstall.exe"

    ; Remove icons and links directories
    RMDir /r "$INSTDIR\Icons"
    RMDir /r "$INSTDIR\Links"

    ; Remove all installed shortcuts
    !insertmacro MUI_STARTMENU_GETFOLDER "Application" $StartMenuGroup
    Delete "$SMPROGRAMS\$StartMenuGroup\DDEV.lnk"
    Delete "$SMPROGRAMS\$StartMenuGroup\DDEV Website.lnk"
    Delete "$SMPROGRAMS\$StartMenuGroup\DDEV Documentation.lnk"
    Delete "$SMPROGRAMS\$StartMenuGroup\Uninstall ${PRODUCT_NAME}.lnk"
    RMDir /r "$SMPROGRAMS\$StartMenuGroup\mkcert"
    RMDir "$SMPROGRAMS\$StartMenuGroup"

    ; Remove registry keys
    DeleteRegKey ${REG_UNINST_ROOT} "${REG_UNINST_KEY}"
    DeleteRegKey ${REG_INSTDIR_ROOT} "${REG_INSTDIR_KEY}"

    ; Remove install directory if empty
    RMDir "$INSTDIR"

    ; Self-delete the uninstaller using ping approach
    SetAutoClose true
    ${If} ${FileExists} "$INSTDIR"
        ExecWait 'cmd.exe /C ping 127.0.0.1 -n 2 && del /F /Q "$EXEPATH"'
    ${EndIf}
SectionEnd

Function GetUbuntuDistros
    DetailPrint "Starting GetUbuntuDistros..."
    StrCpy $R0 ""  ; Result string

    DetailPrint "Checking registry key..."
    SetRegView 64
    ClearErrors
    EnumRegKey $R1 HKCU "Software\Microsoft\Windows\CurrentVersion\Lxss" 0
    ${If} ${Errors}
        DetailPrint "Error accessing Lxss registry key"
        Push ""
        Return
    ${EndIf}
    DetailPrint "Registry key exists and is accessible"

    ; Count total number of keys first
    StrCpy $R1 0   ; Index for enumeration
    StrCpy $R5 0   ; Total count
    count_loop:
        ClearErrors
        EnumRegKey $R2 HKCU "Software\Microsoft\Windows\CurrentVersion\Lxss" $R1
        ${If} ${Errors}
        ${OrIf} $R2 == ""
            Goto count_done
        ${EndIf}
        IntOp $R5 $R5 + 1
        IntOp $R1 $R1 + 1
        Goto count_loop
    count_done:
    DetailPrint "Found $R5 total WSL distributions"

    ; Now enumerate and check each key
    StrCpy $R1 0   ; Reset index
    ${While} $R1 < $R5
        ClearErrors
        EnumRegKey $R2 HKCU "Software\Microsoft\Windows\CurrentVersion\Lxss" $R1
        ${If} ${Errors}
            DetailPrint "Error enumerating key at index $R1"
            Goto next_key
        ${EndIf}

        ClearErrors
        ReadRegStr $R3 HKCU "Software\Microsoft\Windows\CurrentVersion\Lxss\$R2" "DistributionName"
        ${If} ${Errors}
            DetailPrint "Error reading DistributionName for key $R2"
            Goto next_key
        ${EndIf}

        ; Check if it starts with "Ubuntu"
        StrCpy $R4 $R3 6
        ${If} $R4 == "Ubuntu"
            DetailPrint "Found Ubuntu distribution: $R3"
            ${If} $R0 != ""
                StrCpy $R0 "$R0|"
            ${EndIf}
            StrCpy $R0 "$R0$R3"
        ${EndIf}

        next_key:
        IntOp $R1 $R1 + 1
    ${EndWhile}

    DetailPrint "Registry enumeration complete. Final list: [$R0]"
    Push $R0
FunctionEnd


Function InstallWSL2CommonSetup
    ; Check for WSL2
    DetailPrint "Checking WSL2 version..."
    nsExec::ExecToStack 'wsl.exe -l -v'
    Pop $1
    Pop $0
    DetailPrint "WSL version check output: $0"
    DetailPrint "WSL version check exit code: $1"
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "WSL2 does not seem to be installed. Please install WSL2 and Ubuntu before running this installer."
        Abort
    ${EndIf}

    ; Check for Ubuntu in selected distro
    DetailPrint "Checking selected distro $SELECTED_DISTRO..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO bash -c "cat /etc/os-release | grep -i ^NAME="'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Could not access the selected distro. Please ensure it's working properly."
        Abort
    ${EndIf}

    ; Check for WSL2 kernel
    DetailPrint "Checking WSL2 kernel..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO uname -v'
    Pop $1  ; error code
    Pop $0  ; output
    DetailPrint "WSL kernel version: $0"
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Could not check WSL version. Please ensure WSL is working."
        Abort
    ${EndIf}
    ${If} $0 == ""
        MessageBox MB_ICONSTOP|MB_OK "Could not detect WSL version. Please ensure WSL is working."
        Abort
    ${EndIf}
    ${If} $0 == "WSL"
        MessageBox MB_ICONSTOP|MB_OK "Your default WSL distro is not WSL2. Please upgrade to WSL2."
        Abort
    ${EndIf}
    DetailPrint "WSL2 detected successfully."

    ; Check for non-root default user
    DetailPrint "Checking for non-root user..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO whoami'
    Pop $1  ; error code
    Pop $0  ; output
    DetailPrint "Current user: $0"
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Could not check WSL user. Please ensure WSL is working."
        Abort
    ${EndIf}
    ${If} $0 == "root"
        MessageBox MB_ICONSTOP|MB_OK "Default user in your WSL2 distro is root. Please configure an ordinary default user."
        Abort
    ${EndIf}
    DetailPrint "Non-root user detected successfully."

    ; Remove old Docker versions first
    DetailPrint "Removing old Docker versions if present..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root bash -c "apt-get remove -y -qq docker docker-engine docker.io containerd runc >/dev/null 2>&1"'
    Pop $1
    Pop $0

    ; apt-get upgrade
    DetailPrint "Doing apt-get upgrade..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root bash -c "apt-get update && apt-get upgrade -y >/dev/null 2>&1"'
    Pop $1
    Pop $0

    ; Install linux packages
    DetailPrint "Installing linux packages..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root apt-get install -y ca-certificates curl gnupg gnupg2 libsecret-1-0 lsb-release pass'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Failed to install dependencies. Please check the logs."
        Abort
    ${EndIf}

    ; Create keyrings directory if it doesn't exist
    DetailPrint "Setting up keyrings directory..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root install -m 0755 -d /etc/apt/keyrings'
    Pop $1
    Pop $0

    ; Add Docker GPG key
    DetailPrint "Adding Docker repository key..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root bash -c "rm -f /etc/apt/keyrings/docker.gpg && mkdir -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Failed to add Docker repository key. Please check your internet connection. Exit code: $1, Output: $0"
        Abort
    ${EndIf}

    ; Add Docker repository
    DetailPrint "Adding Docker repository..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root -e bash -c "echo deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable | tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1"'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Failed to add Docker repository. Exit code: $1, Output: $0"
        Abort
    ${EndIf}

    ; Add DDEV GPG key
    DetailPrint "Adding DDEV repository key..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root bash -c "curl -fsSL https://pkg.ddev.com/apt/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/ddev.gpg > /dev/null"'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Failed to add DDEV repository key. Error: $0"
        Abort
    ${EndIf}

    ; Add DDEV repository
    DetailPrint "Adding DDEV repository..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root -e bash -c "echo \"deb [signed-by=/etc/apt/keyrings/ddev.gpg] https://pkg.ddev.com/apt/ * *\" > /etc/apt/sources.list.d/ddev.list"'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Failed to add DDEV repository. Please check the logs."
        Abort
    ${EndIf}

    ; Update package lists
    DetailPrint "Updating package lists..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root bash -c "DEBIAN_FRONTEND=noninteractive apt-get update 2>&1"'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Failed to update package lists. Error: $0"
        Abort
    ${EndIf}
FunctionEnd

Function InstallWSL2DockerCE
    DetailPrint "DEBUG: Starting InstallWSL2DockerCE"
    Call InstallWSL2CommonSetup

    ; Install packages for Docker CE
    DetailPrint "Installing packages..."
    StrCpy $0 "ddev docker-ce docker-ce-cli containerd.io wslu"
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y $0 2>&1"'
    Pop $1
    Pop $2
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Failed to install packages. Error: $2"
        Abort
    ${EndIf}

    ; Detect default user in WSL2 (use wsl whoami)
    DetailPrint "Detecting default user in WSL2..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO whoami'
    Pop $1
    Pop $0
    DetailPrint "whoami output: $0"
    ; Remove any trailing newline or carriage return
    Push $0
    Call TrimNewline
    Pop $9
    DetailPrint "Default user detected: $9"

    ; Add user to docker group using root (no sudo)
    DetailPrint "Adding user $9 to docker group with root..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root bash -c "usermod -aG docker $9"'
    Pop $1
    Pop $0
    DetailPrint "usermod output: $0"

    ; Install mkcert root CA in WSL
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root mkcert -install'
    Pop $1
    Pop $0

    ; Remove old .docker config if present
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO rm -rf ~/.docker'
    Pop $1
    Pop $0

    ; Show DDEV version
    DetailPrint "Verifying DDEV installation..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO ddev version'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "DDEV verification failed. Please check the logs."
        Abort
    ${EndIf}

    DetailPrint "All done! Installation completed successfully."
    MessageBox MB_ICONINFORMATION|MB_OK "DDEV WSL2 Docker CE installation completed successfully."
FunctionEnd

Function InstallWSL2DockerDesktop
    DetailPrint "DEBUG: Starting InstallWSL2DockerDesktop"
    Call InstallWSL2CommonSetup

    ; Install packages for Docker Desktop (no docker-ce, only docker-ce-cli and wslu)
    DetailPrint "Installing packages..."
    StrCpy $0 "ddev docker-ce-cli wslu"
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y $0 2>&1"'
    Pop $1
    Pop $2
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "Failed to install packages. Error: $2"
        Abort
    ${EndIf}

    ; Install mkcert root CA in WSL
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO -u root mkcert -install'
    Pop $1
    Pop $0

    ; Remove old .docker config if present
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO rm -rf ~/.docker'
    Pop $1
    Pop $0

    ; Show DDEV version
    DetailPrint "Verifying DDEV installation..."
    nsExec::ExecToStack 'wsl -d $SELECTED_DISTRO ddev version'
    Pop $1
    Pop $0
    ${If} $1 != 0
        MessageBox MB_ICONSTOP|MB_OK "DDEV verification failed. Please check the logs."
        Abort
    ${EndIf}

    DetailPrint "All done! Installation completed successfully."
    MessageBox MB_ICONINFORMATION|MB_OK "DDEV WSL2 Docker Desktop installation completed successfully."
FunctionEnd

Function InstallTraditionalWindows
    DetailPrint "DEBUG: Starting InstallTraditionalWindows"

    SetOutPath $INSTDIR
    SetOverwrite on

    ; Copy core files
    File "..\.gotmp\bin\windows_${TARGET_ARCH}\ddev.exe"
    File "..\.gotmp\bin\windows_${TARGET_ARCH}\ddev-hostname.exe"
    File /oname=license.txt "..\LICENSE"

    ; Install icons
    SetOutPath "$INSTDIR\Icons"
    SetOverwrite try
    File /oname=ddev.ico "graphics\ddev-install.ico"

    ; Create shortcuts
    !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    CreateDirectory "$INSTDIR\Links"
    CreateDirectory "$SMPROGRAMS\$StartMenuGroup"

    ; Use literal names for website and documentation
    WriteIniStr "$INSTDIR\Links\DDEV Website.url" "InternetShortcut" "URL" "https://ddev.com"
    CreateShortCut "$SMPROGRAMS\$StartMenuGroup\DDEV Website.lnk" "$INSTDIR\Links\DDEV Website.url" "" "$INSTDIR\Icons\ddev.ico"

    WriteIniStr "$INSTDIR\Links\DDEV Documentation.url" "InternetShortcut" "URL" "https://ddev.readthedocs.io"
    CreateShortCut "$SMPROGRAMS\$StartMenuGroup\DDEV Documentation.lnk" "$INSTDIR\Links\DDEV Documentation.url" "" "$INSTDIR\Icons\ddev.ico"

    !insertmacro MUI_STARTMENU_WRITE_END

    DetailPrint "Traditional Windows installation completed."
    MessageBox MB_ICONINFORMATION|MB_OK "DDEV Traditional Windows installation completed successfully."
FunctionEnd

Function un.onInit
  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Are you sure you want to completely remove $(^Name) and all of its components?" IDYES DoUninstall
  Abort

DoUninstall:
  ; Switch to 64 bit view and disable FS redirection
  SetRegView 64
  ${DisableX64FSRedirection}
FunctionEnd

Function DirectoryPre
    ${If} $INSTALL_OPTION == "wsl2-docker-ce"
    ${OrIf} $INSTALL_OPTION == "wsl2-docker-desktop"
        ; Skip directory selection for WSL2 installs
        Abort
    ${EndIf}
FunctionEnd

Function ddevLicPre
    ReadRegDWORD $R0 ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "NSIS:ddevLicenseAccepted"
    ${If} $R0 = 1
        Abort
    ${EndIf}
FunctionEnd

Function ddevLicLeave
    WriteRegDWORD ${REG_UNINST_ROOT} "${REG_UNINST_KEY}" "NSIS:ddevLicenseAccepted" 0x00000001
FunctionEnd

Function .onInit
    ; Set proper 64-bit handling
    SetRegView 64
    ${DisableX64FSRedirection}

    ; Initialize directory to proper Program Files location
    ${If} ${RunningX64}
        StrCpy $INSTDIR "$PROGRAMFILES64\${PRODUCT_NAME}"
    ${Else}
        MessageBox MB_ICONSTOP|MB_OK "This installer is for 64-bit Windows only."
        Abort
    ${EndIf}
FunctionEnd

; Helper: returns "1" if $R0 contains $R1, else ""
Function StrContains
    Exch $R1 ; substring
    Exch
    Exch $R0 ; string
    Push $R2
    StrCpy $R2 ""
    ${DoWhile} $R0 != ""
        StrCpy $R2 $R0 6
        StrCmp $R2 $R1 0 found
            Push "1"
            Goto done
        found:
        StrCpy $R0 $R0 "" 1
    ${Loop}
    Push ""
done:
    Pop $R2
    Pop $R1
    Pop $R0
FunctionEnd


; Helper: Trim trailing newline and carriage return from a string
Function TrimNewline
    Exch $R0
    Push $R1
    StrCpy $R1 $R0 -1
    loop_trimnl:
        StrCpy $R1 $R0 -1
        StrCpy $R2 $R1 1 -1
        ${If} $R2 == "$\n"
            StrCpy $R0 $R0 -1
            Goto loop_trimnl
        ${EndIf}
        ${If} $R2 == "$\r"
            StrCpy $R0 $R0 -1
            Goto loop_trimnl
        ${EndIf}
    Pop $R1
    Exch $R0
FunctionEnd
