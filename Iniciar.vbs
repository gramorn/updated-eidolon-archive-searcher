' Iniciar.vbs — Abre o Eidolon Archive sem mostrar janela de terminal
' Clique duplo neste arquivo para iniciar o app.

Set oFS    = CreateObject("Scripting.FileSystemObject")
Set oShell = CreateObject("WScript.Shell")

sDir    = oFS.GetParentFolderName(WScript.ScriptFullName)
sScript = sDir & "\EidolonApp.ps1"

' 0 = janela oculta, True = aguardar conclusao
oShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & sScript & """", 0, True
