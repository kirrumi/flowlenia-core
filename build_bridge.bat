@echo off
set CUDA_PATH_V13_3=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.3
"C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" "%~dp0LeniaUnityBridge\LeniaUnityBridge.vcxproj" /p:Configuration=Release /p:Platform=x64
if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo DLL собрана! Файл:
    echo %~dp0UnityProject\Assets\Plugins\x86_64\LeniaUnityBridge.dll
    echo ========================================
)
pause
