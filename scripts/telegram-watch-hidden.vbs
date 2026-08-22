' HEDEF Kamu — Telegram WATCH arka planda (pencere yok)
Option Explicit

Dim fso, sh, scriptDir, root, bat
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
root = fso.GetParentFolderName(scriptDir)
bat = root & "\TELEGRAM-WATCH.bat"

If Not fso.FileExists(bat) Then
  MsgBox "TELEGRAM-WATCH.bat bulunamadi:" & vbCrLf & bat, vbCritical, "HEDEF Kamu Telegram"
  WScript.Quit 1
End If

sh.Run """" & bat & """ /auto __hidden__", 0, False
