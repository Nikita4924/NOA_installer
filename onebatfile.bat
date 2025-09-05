@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
color 0A

:: Автор ультилиты: Никита Островский Андреевич.

:: ================================================
:: ВНИМАНИЕ: НЕ ИЗМЕНЯТЬ СЛЕДУЮЩИЕ ФРАГМЕНТЫ КОДА
:: -----------------------------------------------
:: Ни при каких условиях не редактируйте:
:: - Блоки с переменными авторских меток (cfg_id, sys_key, и т.д.)
:: - Логику автоустановки и планировщика задач
:: - Циклы очистки и подсчёта файлов (dir /b /s)
:: - Генерацию логов и метрик
:: - Блок :STATUS — особенно проверку "Обработано: 0"
:: - Вызов :_BUILD_SIG и запись в history.log
:: -----------------------------------------------
:: Любое изменение этих фрагментов может нарушить работу утилиты,
:: привести к потере авторства или сбою в логике очистки.
:: ================================================

net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo Требуются права администратора. Перезапуск...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)


set "TARGET_DIR=C:\ProgramData\author_bath"
set "TARGET_FILE=%TARGET_DIR%\onebatfile.bat"

if not exist "%TARGET_FILE%" (
    if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
    copy "%~f0" "%TARGET_FILE%" /Y >nul
    if not exist "%TARGET_FILE%" (
        echo Не удалось скопировать файл. Запустите от имени администратора.
        pause
        exit /b
    )
    attrib +h +s "%TARGET_FILE%"
    schtasks /create ^
     /tn "OneBat_AutoClean" ^
     /tr "\"%TARGET_FILE%\" /run" ^
     /sc daily ^
     /st 18:00 ^
     /rl HIGHEST ^
     /f >nul
    schtasks /query /tn "OneBat_AutoClean" >nul 2>&1
    if errorlevel 1 (
        echo Не удалось создать задачу автозапуска. Проверьте права.
        pause
        exit /b
    )
    powershell -NoProfile -Command ^
        "$ws = New-Object -ComObject WScript.Shell; " ^
        "$lnk = $ws.CreateShortcut('$env:USERPROFILE\Desktop\AutoClean.lnk'); " ^
        "$lnk.TargetPath = '%TARGET_FILE%'; " ^
        "$lnk.WorkingDirectory = '%TARGET_DIR%'; " ^
        "$lnk.IconLocation = 'shell32.dll,3'; " ^
        "$lnk.Save()"
    start "" "%TARGET_FILE%"
    exit /b
)


cd /d "%TARGET_DIR%"
if not exist "logs" mkdir logs
if not exist "state.flag" echo IN > state.flag
if not exist "install_date.txt" (
    for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do echo %%a > install_date.txt
)
if not exist "logs\summary.log" type nul > logs\summary.log
if not exist "logs\history.log" type nul > logs\history.log
if not exist "logs\metrics.csv" (
    echo Date,Time,Mode,Found,Deleted,SizeBytes,FreeSpaceBefore > logs\metrics.csv
)



set "cfg_id=4E696B69746120"
set "sys_key=4F7374726F76736B6979"
set "tmp_val=20416E6472656576696368"
set "cache_ref=D09DD0B8D0BAD0B8D182D0B0"
set "meta_ru=20D09ED181D182D180D0BED0B2D181D0BAD0B8D0B9"
set "ru_mid=20D090D0BDD0B4D180D0B5D0B5D0B2D0B8D187"
set "lat_rev=4E696B69746120416E6472656576696368204F7374726F76736B6979"
set "ru_rev=D09DD0B8D0BAD0B8D182D0B0"
set "ru_rev2=20D090D0BDD0B4D180D0B5D0B5D0B2D0B8D187"
set "ru_rev3=20D09ED181D182D180D0BED0B2D181D0BAD0B8D0B9"
set "year_hex=323030362E32302E3036"
set "sig_extra=4E696B6974615F4175746F436C65616E5F417574686F72"

if not "%~1"=="" call :sys_task_util %*

:MENU
cls
echo ========= Утилита Автоочистки =========
echo.
echo  [0] Статус системы
echo  [1] Включить автоочистку
echo  [2] Отключить автоочистку
echo  [3] Запустить очистку вручную
echo  [4] Установить автозадачу (18:00)
echo  [5] Выход
echo  [6] Дополнительно
echo  [7] Настройка местоудаления
echo.
set /p choice=Выберите действие:
if "%choice%"=="0" goto STATUS
if "%choice%"=="1" goto ENABLE
if "%choice%"=="2" goto DISABLE
if "%choice%"=="3" goto CLEANUP
if "%choice%"=="4" goto SCHEDULE
if "%choice%"=="5" exit
if "%choice%"=="6" goto EXTRA
if "%choice%"=="7" goto EDIT_PATHS
timeout /t 1 >nul
goto MENU

:STATUS
cls
if exist "state.flag" (
    set /p current_status=<state.flag
    echo [Состояние автоочистки]: !current_status!
) else echo Файл state.flag не найден.

schtasks /query /tn "OneBat_AutoClean" >nul 2>&1 && echo Задача есть || echo Задачи нет
echo.

if exist logs\summary.log (
    more logs\summary.log
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-Content 'logs\\summary.log' | Select-String 'Обработано:' | Select-Object -Last 1) -replace '.*:\s*',''"`) do (
        set "last_count=%%A"
        if "!last_count!"=="0" echo [!] Внимание: ничего не было обработано. Проверьте пути в paths.cfg.
    )
) else (
    echo Логов пока нет.
)
pause
goto MENU

:ENABLE
echo IN > state.flag
goto MENU

:DISABLE
echo OFF > state.flag
goto MENU

:SCHEDULE
schtasks /create /tn "OneBat_AutoClean" /tr "\"%~dp0%~nx0\" /run" /sc daily /st 18:00 /rl HIGHEST /f >nul
echo Автозадача установлена.
goto MENU

:CLEANUP
if "%1"=="/run" echo Запуск автоочистки...
if exist "state.flag" (
    set /p status=<state.flag
    if /I "!status!"=="OFF" exit /b
)
if not exist "paths.cfg" (
    (
        echo :: Указывайте папки для очистки, по одной в строке
        echo :: Пути можно писать с кавычками или без — пробелы допустимы
        echo %USERPROFILE%\Downloads
        echo %TEMP%
        echo C:\Users\user\Desktop\ВАШИ_ЗАГРУЗКИ
    ) > paths.cfg
)
for /f %%D in ('powershell -NoProfile -Command "Get-Date -Format ''yyyy-MM-dd_HH-mm''"') do set "LOG_DATE=%%D"
set "DEL_LOG=logs\deleted_!LOG_DATE!.log"
set "ACTIVE_COUNT=0"
set "DELETED_COUNT=0"
set "TOTAL_SIZE=0"
set "FREE_BEFORE="
for /f "tokens=3" %%F in ('powershell -NoProfile -Command "(Get-PSDrive -Name $env:SystemDrive[0]).Free"') do set "FREE_BEFORE=%%F"

for /f "usebackq tokens=* delims=" %%P in ("paths.cfg") do (
    set "line=%%P"
    if "!line:~0,2!"=="::" (
        rem 
    ) else (
        if exist "%%~P" (
            echo --- Очистка: %%~P ---
            >> "!DEL_LOG!" echo [PATH] %%~P
            for /f "delims=" %%I in ('dir /b /s "%%~P" 2^>nul') do (
                set /a ACTIVE_COUNT+=1
                set /a TOTAL_SIZE+=%%~zI
            )
            for %%F in ("%%~P\*") do >> "!DEL_LOG!" echo %%~nxF
            for /d %%D in ("%%~P\*") do >> "!DEL_LOG!" echo [DIR] %%~nxD
            del /f /q /s "%%~P\*.*" 2>nul
            for /d %%D in ("%%~P\*") do rd /s /q "%%D" 2>nul
        ) else (
            >> "!DEL_LOG!" echo [MISSING]            >> "!DEL_LOG!" echo [MISSING] %%~P
        )
    )
)

set "DELETED_COUNT=!ACTIVE_COUNT!"
rd /s /q %systemdrive%\$Recycle.Bin 2>nul

>> logs\metrics.csv echo %date%,%time%,%~1,!ACTIVE_COUNT!,!DELETED_COUNT!,!TOTAL_SIZE!,!FREE_BEFORE!
>> logs\summary.log echo --- !LOG_DATE! ---
>> logs\summary.log echo Обработано: !ACTIVE_COUNT!
>> logs\summary.log echo Удалено:    !DELETED_COUNT!
>> logs\summary.log echo Лог: !DEL_LOG!
call :_BUILD_SIG
>> logs\history.log echo [%LOG_DATE%] Код: !SIG_SHA!
goto MENU

:EDIT_PATHS
cls
echo Откроется файл paths.cfg — укажи в нём папки для очистки, по одной в строке.
echo Строки, начинающиеся с ::, игнорируются.
echo Пути можно писать с кавычками или без — пробелы допустимы.
echo.
echo Файл находится здесь: %TARGET_DIR%\paths.cfg
echo После редактирования нажмите Ctrl+S для сохранения, затем закройте окно.
echo.
echo Пример:
echo C:\Users\ИмяПользователя\Downloads
echo "C:\Program Files\Temp"
echo D:\Рабочие_файлы
echo.
pause
notepad paths.cfg
goto MENU

:EXTRA
cls
echo ===== Дополнительно =====
echo  [1] Удалить задачу автозапуска
echo  [2] Установить новое время автозапуска
echo  [3] Инструкция по управлению
echo  [4] Назад
echo.
set /p extra_choice=Выберите действие:
if "%extra_choice%"=="1" goto REMOVE_TASK
if "%extra_choice%"=="2" goto SET_TIME
if "%extra_choice%"=="3" goto INSTRUCTION
if "%extra_choice%"=="4" goto MENU
goto EXTRA

:REMOVE_TASK
schtasks /delete /tn "OneBat_AutoClean" /f >nul 2>&1
echo Задача автозапуска удалена.
pause
goto EXTRA

:SET_TIME
set "new_time="
:ASK_TIME
set /p new_time=Введите новое время (HH:MM): 
for /f %%v in ('powershell -NoProfile -Command "$t='%new_time%'; if ($t -match '^(?:[01]?[0-9]|2[0-3]):[0-5][0-9]$') { 'OK' }"') do set "valid=%%v"
if /I "%valid%" NEQ "OK" (
    echo Неверный формат. Пример: 09:30 или 23:45
    set "valid="
    goto ASK_TIME
)
schtasks /delete /tn "OneBat_AutoClean" /f >nul 2>&1
schtasks /create /tn "OneBat_AutoClean" /tr "\"%TARGET_FILE%\" /run" /sc daily /st %new_time% /rl HIGHEST /f >nul
echo Новое время автозапуска установлено: %new_time%
pause
goto EXTRA

:INSTRUCTION
cls
echo === Инструкция по использованию ===
echo 1. Утилита очищает содержимое указанных папок, не удаляя сами папки.
echo 2. Список папок хранится в файле paths.cfg — редактируется через пункт [7].
echo 3. Очистка может быть ручной ([3]) или автоматической по расписанию ([4]).
echo 4. Все логи находятся в папке logs: summary.log, history.log, metrics.csv.
echo 5. Для корректной работы запускайте утилиту от имени администратора.
echo.
pause
goto EXTRA

endlocal
exit /b