@echo off
set "startup_folder=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "shortcut_name=ADB WiFi Connector.lnk"
set "app_path=%~dp0build\windows\runner\Release\adb_wifi_connector.exe"

:: 创建快捷方式
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut('%startup_folder%\%shortcut_name%'); $SC.TargetPath = '%app_path%'; $SC.Save()"

:: 启动应用
start "" "%app_path%" 