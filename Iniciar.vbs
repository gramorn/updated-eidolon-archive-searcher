' Iniciar.vbs - Opens Eidolon Archive without showing a terminal window
' Double-click this file to start the app.

Set oFS    = CreateObject("Scripting.FileSystemObject")
Set oShell = CreateObject("WScript.Shell")

sDir    = oFS.GetParentFolderName(WScript.ScriptFullName)
sScript = sDir & "\EidolonApp.ps1"

' 0 = hidden window, True = wait until completion
oShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & sScript & """", 0, True
