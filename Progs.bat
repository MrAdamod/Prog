@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

set "LINKSDIR=%~dp0links"
set "LINKS_OPEN=%LINKSDIR%\links.txt"
set "LINKS_DL=%LINKSDIR%\links_download.txt"
set "REGLIST=%LINKSDIR%\registry.txt"
set "PROGS=%~dp0Progs"
set "LOGDIR=%~dp0Logs"
set "PROFILESDIR=%~dp0profiles"
set "VERSION=2.1"
set "QUIT=0"

if not exist "%LINKSDIR%" mkdir "%LINKSDIR%"
if not exist "%PROGS%" mkdir "%PROGS%"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
if not exist "%PROFILESDIR%" mkdir "%PROFILESDIR%"

set "SESSIONLOG=%LOGDIR%\session-report_%COMPUTERNAME%_%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%.txt"
set "SESSIONLOG=%SESSIONLOG: =0%"
echo === Сессия начата: %date% %time% === > "%SESSIONLOG%"
echo Компьютер: %COMPUTERNAME% >> "%SESSIONLOG%"
echo Пользователь: %USERNAME% >> "%SESSIONLOG%"
echo Версия скрипта: %VERSION% >> "%SESSIONLOG%"
echo. >> "%SESSIONLOG%"

:main_menu
cls
call :folder_size
call :check_internet
call :check_admin

echo ============================================
echo   ПК: %COMPUTERNAME%   Пользователь: %USERNAME%
echo      Progs: !fcount! файлов, !fsize! МБ
echo      Интернет: !NETSTATUS!
echo      Права администратора: !ADMINSTATUS!
echo ============================================
echo   Главное меню - версия !VERSION!
echo ============================================
echo   [1] Скачать программы
echo   [2] Установка из Progs
echo   [3] Удалить из Progs
echo   [4] Открыть ссылки
echo   [5] Открыть txt
echo   [6] Показать логи
echo   [7] Удалить разделы реестра
echo   [8] Установить по пресету
echo   [9] Перезапустить от администратора
echo   [10] О программе
echo   [0] Выход
echo ============================================
set /p "mainchoice=Выберите пункт: "

if "!mainchoice!"=="1" call :download
if "!mainchoice!"=="2" call :install
if "!mainchoice!"=="3" call :delete
if "!mainchoice!"=="4" call :openlinks
if "!mainchoice!"=="5" call :opentxt
if "!mainchoice!"=="6" call :logsmenu
if "!mainchoice!"=="7" call :regclean
if "!mainchoice!"=="8" call :installprofile
if "!mainchoice!"=="9" call :elevate
if "!mainchoice!"=="10" call :about
if "!QUIT!"=="1" (
    echo. >> "%SESSIONLOG%"
    echo === Сессия завершена - перезапуск от администратора: %date% %time% === >> "%SESSIONLOG%"
    exit /b
)
if "!mainchoice!"=="0" (
    echo. >> "%SESSIONLOG%"
    echo === Сессия завершена: %date% %time% === >> "%SESSIONLOG%"
    exit /b
)

goto main_menu


:: ============================================
:: Разбор диапазонов (1-3 6 8-10) -> selected
:: ============================================
:parse_selection
set "selected="
if /i "!choice!"=="A" (
    for /l %%i in (1,1,!total!) do set "selected=!selected! %%i"
    exit /b
)
for %%P in (!choice!) do (
    set "part=%%P"
    set "test=!part!"
    set "test=!test:-= !"

    if "!test!"=="!part!" (
        set "selected=!selected! !part!"
    ) else (
        for /f "tokens=1,2 delims=-" %%a in ("!part!") do (
            set "from=%%a"
            set "to=%%b"
            if defined from if defined to (
                for /l %%k in (!from!,1,!to!) do set "selected=!selected! %%k"
            )
        )
    )
)
exit /b


:: ============================================
:: Размер и число файлов в Progs
:: ============================================
:folder_size
set "fcount=0"
set "fsize=0"
for /f %%C in ('dir /a-d /b "%PROGS%" 2^>nul ^| find /c /v ""') do set "fcount=%%C"
for /f %%S in ('powershell -NoProfile -Command "try{[math]::Round((Get-ChildItem -Path '%PROGS%' -File -Recurse -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum/1MB,1)}catch{0}"') do set "fsize=%%S"
exit /b


:: ============================================
:: Проверка интернет-соединения
:: ============================================
:check_internet
ping -n 1 -w 1000 8.8.8.8 >nul 2>&1
if !errorlevel! equ 0 (
    set "NETSTATUS=есть"
) else (
    set "NETSTATUS=НЕТ ДОСТУПА"
)
exit /b


:: ============================================
:: Проверка прав администратора
:: ============================================
:check_admin
net session >nul 2>&1
if !errorlevel! equ 0 (
    set "ADMINSTATUS=Да"
) else (
    set "ADMINSTATUS=НЕТ"
)
exit /b


:: ============================================
:: Показать логи (по типу процесса)
:: ============================================
:logsmenu
setlocal enabledelayedexpansion

:logsmenu_loop
cls
echo ============================================
echo   Какой лог показать?
echo ============================================
echo   [1] Последний лог скачивания
echo   [2] Последний лог установки
echo   [3] Последний лог удаления
echo   [4] Последний лог очистки реестра
echo   [5] Последний лог установки по пресету
echo   [0] Назад
echo ============================================
set /p "lchoice=Выберите пункт: "

if "!lchoice!"=="1" (
    set "PREFIX=download-log_"
    call :show_one_log
    goto logsmenu_loop
)
if "!lchoice!"=="2" (
    set "PREFIX=install-log_"
    call :show_one_log
    goto logsmenu_loop
)
if "!lchoice!"=="3" (
    set "PREFIX=delete-log_"
    call :show_one_log
    goto logsmenu_loop
)
if "!lchoice!"=="4" (
    set "PREFIX=regclean-log_"
    call :show_one_log
    goto logsmenu_loop
)
if "!lchoice!"=="5" (
    set "PREFIX=profile-log_"
    call :show_one_log
    goto logsmenu_loop
)
if "!lchoice!"=="0" (
    endlocal
    exit /b
)

goto logsmenu_loop


:show_one_log
set "latest="
for /f "delims=" %%F in ('dir /b /o-d "%LOGDIR%\!PREFIX!*.txt" 2^>nul') do (
    if not defined latest set "latest=%%F"
)
if not defined latest (
    echo Логов такого типа пока нет.
    pause
    exit /b
)
cls
echo ============================================
echo   Последний лог: !latest!
echo ============================================
type "%LOGDIR%\!latest!"
echo ============================================
pause
exit /b


:: ============================================
:: 1) СКАЧИВАНИЕ
:: ============================================
:download
setlocal enabledelayedexpansion

if not exist "%LINKS_DL%" (
    echo Файл links_download.txt не найден в папке links!
    pause
    endlocal
    exit /b
)

set total=0

for /f "usebackq tokens=1,2 delims=|" %%L in ("%LINKS_DL%") do (
    if not "%%L"=="" (
        set "u=%%L"
        set "n=%%M"

        for /f "tokens=* delims= " %%a in ("!u!") do set "u=%%a"
        for /l %%z in (1,1,100) do if "!u:~-1!"==" " set "u=!u:~0,-1!"
        for /f "tokens=* delims= " %%a in ("!n!") do set "n=%%a"
        for /l %%z in (1,1,100) do if "!n:~-1!"==" " set "n=!n:~0,-1!"

        if not "!n!"=="" (
            set /a total+=1
            set "item!total!_url=!u!"
            set "item!total!_name=!n!"
        )
    )
)

if !total! equ 0 (
    echo В links_download.txt не найдено ни одной ссылки с именем файла ^(формат: url^|имя.exe^).
    pause
    endlocal
    exit /b
)

echo ============================================
echo   Доступные файлы для скачивания:
echo ============================================
for /l %%i in (1,1,!total!) do (
    if exist "%PROGS%\!item%%i_name!" (
        echo   [%%i] !item%%i_name!  ^(уже скачан^)
    ) else (
        echo   [%%i] !item%%i_name!
    )
)
echo   [A] Скачать всё
echo   [0] Отмена
echo ============================================
echo   Можно указывать диапазоны через тире, например: 1-3 6 8-10
set /p "choice=Введите номера, A для всех, 0 для отмены: "

if "!choice!"=="0" (
    echo Отменено.
    pause
    endlocal
    exit /b
)
if /i "!choice!"=="C" (
    echo Отменено.
    pause
    endlocal
    exit /b
)
if "!choice!"=="" (
    echo Ничего не выбрано.
    pause
    endlocal
    exit /b
)

call :parse_selection

if "!selected!"=="" (
    echo Некорректный ввод.
    pause
    endlocal
    exit /b
)

set "LOG=%LOGDIR%\download-log_%COMPUTERNAME%_%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%.txt"
set "LOG=%LOG: =0%"

echo === Скачивание начато: %date% %time% === > "%LOG%"
if not exist "%LOG%" (
    echo ВНИМАНИЕ: не удалось создать файл лога по пути:
    echo %LOG%
    echo Проверьте права доступа к папке Logs и её наличие.
    echo Работа продолжится без записи лога.
    pause
)
echo Компьютер: %COMPUTERNAME% >> "%LOG%"
echo Пользователь: %USERNAME% >> "%LOG%"
echo Выбрано: !selected! >> "%LOG%"
echo. >> "%LOG%"

set downloaded=0
set skipped=0
set errors=0

for %%N in (!selected!) do (
    set "url=!item%%N_url!"
    set "name=!item%%N_name!"

    if not "!url!"=="" (
        if exist "%PROGS%\!name!" (
            echo Уже есть: !name! - пропускаю
            echo Уже есть: !name! >> "%LOG%"
            set /a skipped+=1
        ) else (
            echo Скачиваю: !name! ...
            echo Скачиваю: !name! >> "%LOG%"

            curl -L -o "%PROGS%\!name!" "!url!"

            if exist "%PROGS%\!name!" (
                echo   Скачано успешно >> "%LOG%"
                set /a downloaded+=1
            ) else (
                echo   ОШИБКА: не удалось скачать !name! >> "%LOG%"
                echo ОШИБКА: !name! не скачался
                set /a errors+=1
            )
        )
    )
)

echo. >> "%LOG%"
echo === Скачивание завершено: %date% %time% === >> "%LOG%"
echo Скачано: !downloaded!, пропущено: !skipped!, ошибок: !errors! >> "%LOG%"

echo [%time%] Скачивание - скачано !downloaded!, пропущено !skipped!, ошибок !errors! ^(лог: !LOG:*\=!^) >> "%SESSIONLOG%"

echo.
echo Скачивание завершено. Скачано: !downloaded!, пропущено: !skipped!, ошибок: !errors!
echo Лог: %LOG%
pause
endlocal
exit /b


:: ============================================
:: 2) УСТАНОВКА
:: ============================================
:install
setlocal enabledelayedexpansion

set total=0

for %%F in ("%PROGS%\*.exe" "%PROGS%\*.msi") do (
    if exist "%%F" (
        set /a total+=1
        set "item!total!_name=%%~nxF"
        set "item!total!_path=%%F"
    )
)

if !total! equ 0 (
    echo В папке Progs не найдено ни одного exe или msi файла.
    pause
    endlocal
    exit /b
)

echo ============================================
echo   Доступные программы для установки:
echo ============================================
for /l %%i in (1,1,!total!) do (
    echo   [%%i] !item%%i_name!
)
echo   [A] Установить всё
echo   [0] Отмена
echo ============================================
echo   Можно указывать диапазоны через тире, например: 1-3 6 8-10
set /p "choice=Введите номера, A для всех, 0 для отмены: "

if "!choice!"=="0" (
    echo Установка отменена.
    pause
    endlocal
    exit /b
)
if /i "!choice!"=="C" (
    echo Установка отменена.
    pause
    endlocal
    exit /b
)
if "!choice!"=="" (
    echo Ничего не выбрано.
    pause
    endlocal
    exit /b
)

call :parse_selection

if "!selected!"=="" (
    echo Некорректный ввод.
    pause
    endlocal
    exit /b
)

set "LOG=%LOGDIR%\install-log_%COMPUTERNAME%_%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%.txt"
set "LOG=%LOG: =0%"

echo === Установка начата: %date% %time% === > "%LOG%"
if not exist "%LOG%" (
    echo ВНИМАНИЕ: не удалось создать файл лога по пути:
    echo %LOG%
    echo Проверьте права доступа к папке Logs и её наличие.
    echo Работа продолжится без записи лога.
    pause
)
echo Компьютер: %COMPUTERNAME% >> "%LOG%"
echo Пользователь: %USERNAME% >> "%LOG%"
echo Выбрано: !selected! >> "%LOG%"
echo. >> "%LOG%"

set installed=0
set errors=0

for %%N in (!selected!) do (
    set "name=!item%%N_name!"
    set "path=!item%%N_path!"

    if not "!name!"=="" (
        set /a installed+=1

        echo Устанавливаю: !name!
        echo [!installed!] !name! >> "%LOG%"
        echo   Начало: %date% %time% >> "%LOG%"

        if /i "!name:~-4!"==".msi" (
            start /wait "" msiexec /i "!path!"
        ) else (
            start /wait "" "!path!"
        )

        set "code=!errorlevel!"
        echo   Конец: %date% %time% >> "%LOG%"
        echo   Код завершения: !code! >> "%LOG%"

        if "!code!"=="0" (
            echo   Статус: Успешно >> "%LOG%"
        ) else if "!code!"=="1602" (
            echo   Статус: ОТМЕНЕНО пользователем >> "%LOG%"
            set /a errors+=1
        ) else if "!code!"=="1223" (
            echo   Статус: ОТМЕНЕНО пользователем >> "%LOG%"
            set /a errors+=1
        ) else if "!code!"=="3010" (
            echo   Статус: Успешно, требуется перезагрузка >> "%LOG%"
        ) else (
            echo   Статус: Возможна ошибка ^(код !code!^) >> "%LOG%"
            set /a errors+=1
        )

        echo. >> "%LOG%"
    )
)

echo === Установка завершена: %date% %time% === >> "%LOG%"
echo Установлено: !installed!, проблемных: !errors! >> "%LOG%"

echo [%time%] Установка - установлено !installed!, проблемных !errors! ^(лог: !LOG:*\=!^) >> "%SESSIONLOG%"

echo.
echo Установка завершена. Установлено: !installed!, проблемных: !errors!
echo Лог: %LOG%
pause
endlocal
exit /b


:: ============================================
:: 3) УДАЛЕНИЕ ПРОГРАММ ИЗ PROGS
:: ============================================
:delete
setlocal enabledelayedexpansion

set total=0

for %%F in ("%PROGS%\*.exe" "%PROGS%\*.msi") do (
    if exist "%%F" (
        set /a total+=1
        set "item!total!_name=%%~nxF"
        set "item!total!_path=%%F"
    )
)

if !total! equ 0 (
    echo В папке Progs не найдено ни одного exe или msi файла.
    pause
    endlocal
    exit /b
)

echo ============================================
echo   Доступные программы для удаления:
echo ============================================
for /l %%i in (1,1,!total!) do (
    echo   [%%i] !item%%i_name!
)
echo   [A] Удалить всё
echo   [0] Отмена
echo ============================================
echo   Можно указывать диапазоны через тире, например: 1-3 6 8-10
set /p "choice=Введите номера, A для всех, 0 для отмены:"

if "!choice!"=="0" (
    echo Удаление отменено.
    pause
    endlocal
    exit /b
)
if /i "!choice!"=="C" (
    echo Удаление отменено.
    pause
    endlocal
    exit /b
)
if "!choice!"=="" (
    echo Ничего не выбрано.
    pause
    endlocal
    exit /b
)

call :parse_selection

if "!selected!"=="" (
    echo Некорректный ввод.
    pause
    endlocal
    exit /b
)

choice /c YN /m "Удалить выбранные файлы безвозвратно"
if !errorlevel! neq 1 (
    echo Удаление отменено.
    pause
    endlocal
    exit /b
)

set "LOG=%LOGDIR%\delete-log_%COMPUTERNAME%_%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%.txt"
set "LOG=%LOG: =0%"

echo === Удаление начато: %date% %time% === > "%LOG%"
if not exist "%LOG%" (
    echo ВНИМАНИЕ: не удалось создать файл лога по пути:
    echo %LOG%
    echo Проверьте права доступа к папке Logs и её наличие.
    echo Работа продолжится без записи лога.
    pause
)
echo Компьютер: %COMPUTERNAME% >> "%LOG%"
echo Пользователь: %USERNAME% >> "%LOG%"
echo Выбрано: !selected! >> "%LOG%"
echo. >> "%LOG%"

set deleted=0
for %%N in (!selected!) do (
    set "name=!item%%N_name!"
    set "path=!item%%N_path!"
    if not "!name!"=="" (
        if exist "!path!" (
            del "!path!" 2>nul
            echo Удалён: !name! >> "%LOG%"
            set /a deleted+=1
        )
    )
)

echo. >> "%LOG%"
echo === Удаление завершено: %date% %time% === >> "%LOG%"
echo Удалено файлов: !deleted! >> "%LOG%"

echo [%time%] Удаление - удалено файлов !deleted! ^(лог: !LOG:*\=!^) >> "%SESSIONLOG%"

echo.
echo Удалено файлов: !deleted!
echo Лог: %LOG%
pause
endlocal
exit /b


:: ============================================
:: 4) ОТКРЫТИЕ ССЫЛОК
:: ============================================
:openlinks
setlocal enabledelayedexpansion

if not exist "%LINKS_OPEN%" (
    echo Файл links.txt не найден в папке links!
    pause
    endlocal
    exit /b
)

set total=0

for /f "usebackq tokens=1,2 delims=|" %%L in ("%LINKS_OPEN%") do (
    if not "%%L"=="" (
        set "u=%%L"
        set "n=%%M"

        for /f "tokens=* delims= " %%a in ("!u!") do set "u=%%a"
        for /l %%z in (1,1,100) do if "!u:~-1!"==" " set "u=!u:~0,-1!"
        for /f "tokens=* delims= " %%a in ("!n!") do set "n=%%a"
        for /l %%z in (1,1,100) do if "!n:~-1!"==" " set "n=!n:~0,-1!"

        set /a total+=1
        set "item!total!_url=!u!"
        if "!n!"=="" (
            set "item!total!_name=!u!"
        ) else (
            set "item!total!_name=!n!"
        )
    )
)

if !total! equ 0 (
    echo В links.txt не найдено ни одной ссылки.
    pause
    endlocal
    exit /b
)

echo ============================================
echo   Доступные ссылки:
echo ============================================
for /l %%i in (1,1,!total!) do (
    echo   [%%i] !item%%i_name!
)
echo   [A] Открыть все
echo   [0] Отмена
echo ============================================
echo   Можно указывать диапазоны через тире, например: 1-3 6 8-10
set /p "choice=Введите номера, A для всех, 0 для отмены: "

if "!choice!"=="0" (
    echo Отменено.
    pause
    endlocal
    exit /b
)
if /i "!choice!"=="C" (
    echo Отменено.
    pause
    endlocal
    exit /b
)
if "!choice!"=="" (
    echo Ничего не выбрано.
    pause
    endlocal
    exit /b
)

call :parse_selection

if "!selected!"=="" (
    echo Некорректный ввод.
    pause
    endlocal
    exit /b
)

for %%N in (!selected!) do (
    set "url=!item%%N_url!"
    set "name=!item%%N_name!"
    if not "!url!"=="" (
        echo Открываю: !name!
        start "" "!url!"
    )
)

echo.
echo Готово.
pause
endlocal
exit /b


:: ============================================
:: 5) Работа с txt файлами
:: ============================================
:opentxt
setlocal enabledelayedexpansion

:opentxt_menu
cls
echo ============================================
echo   Работа с txt файлами
echo ============================================
echo   [1] Открыть links.txt (ссылки для браузера)
echo   [2] Открыть links_download.txt (ссылки для скачивания)
echo   [3] Добавить ссылку в links.txt
echo   [4] Добавить ссылку в links_download.txt
echo   [0] Назад
echo ============================================
set /p "tchoice=Выберите пункт: "

if "!tchoice!"=="1" (
    if not exist "%LINKS_OPEN%" type nul > "%LINKS_OPEN%"
    start "" "%LINKS_OPEN%"
    goto opentxt_menu
)
if "!tchoice!"=="2" (
    if not exist "%LINKS_DL%" type nul > "%LINKS_DL%"
    start "" "%LINKS_DL%"
    goto opentxt_menu
)
if "!tchoice!"=="3" (
    call :addlink_open
    goto opentxt_menu
)
if "!tchoice!"=="4" (
    call :addlink_download
    goto opentxt_menu
)
if "!tchoice!"=="0" (
    endlocal
    exit /b
)

goto opentxt_menu


:addlink_open
set "newurl="
set "newname="
set /p "newurl=Введите ссылку (URL): "
if "!newurl!"=="" (
    echo Ссылка не введена, отмена.
    pause
    exit /b
)
set /p "newname=Введите название для меню (необязательно, Enter - пропустить): "
if not exist "%LINKS_OPEN%" type nul > "%LINKS_OPEN%"
if "!newname!"=="" (
    echo !newurl!>> "%LINKS_OPEN%"
) else (
    echo !newurl!^|!newname!>> "%LINKS_OPEN%"
)
echo.
echo Ссылка добавлена в links.txt
pause
exit /b


:addlink_download
set "newurl="
set "newname="
set /p "newurl=Введите ссылку (URL): "
if "!newurl!"=="" (
    echo Ссылка не введена, отмена.
    pause
    exit /b
)
:addlink_download_name
set "newname="
set /p "newname=Введите имя файла с расширением (например app.exe): "
if "!newname!"=="" (
    echo Имя файла обязательно для links_download.txt.
    goto addlink_download_name
)
if not exist "%LINKS_DL%" type nul > "%LINKS_DL%"
echo !newurl!^|!newname!>> "%LINKS_DL%"
echo.
echo Ссылка добавлена в links_download.txt
pause
exit /b




:: ============================================
:: Удаление разделов реестра (по списку registry.txt)
:: ============================================
:regclean
setlocal enabledelayedexpansion

if not exist "%REGLIST%" (
    echo Файл registry.txt не найден в папке links!
    pause
    endlocal
    exit /b
)

call :check_admin
if "!ADMINSTATUS!"=="НЕТ" (
    echo ВНИМАНИЕ: нет прав администратора.
    echo Удаление разделов HKLM без них не сработает.
    echo Используйте пункт [9] главного меню для перезапуска
    echo от имени администратора и повторите.
    pause
    endlocal
    exit /b
)

set total=0
for /f "usebackq tokens=1,2 delims=|" %%L in ("%REGLIST%") do (
    if not "%%L"=="" (
        set "u=%%L"
        set "n=%%M"
        for /f "tokens=* delims= " %%a in ("!u!") do set "u=%%a"
        for /l %%z in (1,1,200) do if "!u:~-1!"==" " set "u=!u:~0,-1!"
        for /f "tokens=* delims= " %%a in ("!n!") do set "n=%%a"
        for /l %%z in (1,1,100) do if "!n:~-1!"==" " set "n=!n:~0,-1!"
        if not "!n!"=="" (
            set /a total+=1
            set "item!total!_path=!u!"
            set "item!total!_name=!n!"
        )
    )
)

if !total! equ 0 (
    echo В registry.txt не найдено ни одной записи.
    pause
    endlocal
    exit /b
)

echo ============================================
echo   Доступные разделы реестра для удаления:
echo ============================================
for /l %%i in (1,1,!total!) do (
    echo   [%%i] !item%%i_name!
)
echo   [A] Удалить все
echo   [0] Отмена
echo ============================================
echo   Можно указывать диапазоны через тире, например: 1-3 6 8-10
set /p "choice=Введите номера, A для всех, 0 для отмены: "

if "!choice!"=="0" (
    echo Отменено.
    pause
    endlocal
    exit /b
)
if /i "!choice!"=="C" (
    echo Отменено.
    pause
    endlocal
    exit /b
)
if "!choice!"=="" (
    echo Ничего не выбрано.
    pause
    endlocal
    exit /b
)

call :parse_selection

if "!selected!"=="" (
    echo Некорректный ввод.
    pause
    endlocal
    exit /b
)

choice /c YN /m "Удалить выбранные разделы реестра безвозвратно"
if !errorlevel! neq 1 (
    echo Отменено.
    pause
    endlocal
    exit /b
)

set "LOG=%LOGDIR%\regclean-log_%COMPUTERNAME%_%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%.txt"
set "LOG=%LOG: =0%"

echo === Очистка реестра начата: %date% %time% === > "%LOG%"
echo Компьютер: %COMPUTERNAME% >> "%LOG%"
echo Пользователь: %USERNAME% >> "%LOG%"
echo Выбрано: !selected! >> "%LOG%"
echo. >> "%LOG%"

set removed=0
set regerrors=0

for %%N in (!selected!) do (
    set "rpath=!item%%N_path!"
    set "rname=!item%%N_name!"
    if not "!rpath!"=="" (
        echo Удаляю: !rname!
        echo [!rname!] !rpath! >> "%LOG%"

        reg delete "!rpath!" /f >nul 2>&1
        set "code=!errorlevel!"
        echo   Код завершения: !code! >> "%LOG%"
        if "!code!"=="0" (
            echo   Статус: Удалено >> "%LOG%"
            set /a removed+=1
        ) else (
            echo   Статус: Не найдено или ошибка >> "%LOG%"
            set /a regerrors+=1
        )
        echo. >> "%LOG%"
    )
)

echo === Очистка реестра завершена: %date% %time% === >> "%LOG%"
echo Удалено: !removed!, не найдено/ошибок: !regerrors! >> "%LOG%"

echo [%time%] Очистка реестра - удалено !removed!, ошибок !regerrors! ^(лог: !LOG:*\=!^) >> "%SESSIONLOG%"

echo.
echo Готово. Удалено: !removed!, не найдено/ошибок: !regerrors!
echo Лог: %LOG%
pause
endlocal
exit /b


:: ============================================
:: Установка по пресету (profiles\*.txt)
:: ============================================
:installprofile
setlocal enabledelayedexpansion

set total=0
for %%F in ("%PROFILESDIR%\*.txt") do (
    if exist "%%F" (
        set /a total+=1
        set "item!total!_name=%%~nF"
        set "item!total!_path=%%F"
    )
)

if !total! equ 0 (
    echo В папке profiles не найдено ни одного txt-файла с пресетом.
    pause
    endlocal
    exit /b
)

echo ============================================
echo   Доступные пресеты:
echo ============================================
for /l %%i in (1,1,!total!) do (
    echo   [%%i] !item%%i_name!
)
echo   [0] Отмена
echo ============================================
set /p "pchoice=Выберите пресет: "

if "!pchoice!"=="0" (
    echo Отменено.
    pause
    endlocal
    exit /b
)
if "!pchoice!"=="" (
    echo Ничего не выбрано.
    pause
    endlocal
    exit /b
)

set "profilefile="
set "profilename="
for /l %%i in (1,1,!total!) do (
    if "!pchoice!"=="%%i" (
        set "profilefile=!item%%i_path!"
        set "profilename=!item%%i_name!"
    )
)

if "!profilefile!"=="" (
    echo Некорректный выбор.
    pause
    endlocal
    exit /b
)

set pcount=0
for /f "usebackq delims=" %%L in ("!profilefile!") do (
    if not "%%L"=="" (
        set /a pcount+=1
        set "pitem!pcount!=%%L"
    )
)

if !pcount! equ 0 (
    echo Пресет пуст.
    pause
    endlocal
    exit /b
)

set need=0
set missing=0

for /l %%i in (1,1,!pcount!) do (
    set "pname=!pitem%%i!"
    if exist "%PROGS%\!pname!" (
        set /a need+=1
        set "need!need!=!pname!"
        set "needsrc!need!=local"
    ) else (
        set "found_url="
        if exist "%LINKS_DL%" (
            for /f "usebackq tokens=1,2 delims=|" %%A in ("%LINKS_DL%") do (
                set "chkn=%%B"
                for /f "tokens=* delims= " %%z in ("!chkn!") do set "chkn=%%z"
                if /i "!chkn!"=="!pname!" set "found_url=%%A"
            )
        )
        if defined found_url (
            set /a need+=1
            set "need!need!=!pname!"
            set "needsrc!need!=download"
            set "needurl!need!=!found_url!"
        ) else (
            set /a missing+=1
            set "miss!missing!=!pname!"
        )
    )
)

echo ============================================
echo   Пресет: !profilename!
echo ============================================
echo   Будет обработано: !need!
if !missing! gtr 0 (
    echo   Не найдено нигде ^(ни локально, ни в links_download.txt^): !missing!
    for /l %%i in (1,1,!missing!) do echo     - !miss%%i!
)
echo ============================================

if !need! equ 0 (
    echo Нечего устанавливать.
    pause
    endlocal
    exit /b
)

choice /c YN /m "Продолжить"
if !errorlevel! neq 1 (
    echo Отменено.
    pause
    endlocal
    exit /b
)

set "LOG=%LOGDIR%\profile-log_%COMPUTERNAME%_%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%.txt"
set "LOG=%LOG: =0%"

echo === Установка по пресету начата: %date% %time% === > "%LOG%"
echo Пресет: !profilename! >> "%LOG%"
echo Компьютер: %COMPUTERNAME% >> "%LOG%"
echo Пользователь: %USERNAME% >> "%LOG%"
echo. >> "%LOG%"

if !missing! gtr 0 (
    echo Не найдено: >> "%LOG%"
    for /l %%i in (1,1,!missing!) do echo   - !miss%%i! >> "%LOG%"
    echo. >> "%LOG%"
)

set dlok=0
set dlerr=0
for /l %%i in (1,1,!need!) do (
    if "!needsrc%%i!"=="download" (
        echo Скачиваю: !need%%i! ...
        echo Скачиваю: !need%%i! >> "%LOG%"
        curl -L -o "%PROGS%\!need%%i!" "!needurl%%i!"
        if exist "%PROGS%\!need%%i!" (
            echo   Скачано успешно >> "%LOG%"
            set /a dlok+=1
        ) else (
            echo   ОШИБКА: не удалось скачать >> "%LOG%"
            set /a dlerr+=1
        )
    )
)

echo. >> "%LOG%"

set installed=0
set insterr=0
for /l %%i in (1,1,!need!) do (
    if exist "%PROGS%\!need%%i!" (
        echo Устанавливаю: !need%%i!
        echo Устанавливаю: !need%%i! >> "%LOG%"

        if /i "!need%%i:~-4!"==".msi" (
            start /wait "" msiexec /i "%PROGS%\!need%%i!"
        ) else (
            start /wait "" "%PROGS%\!need%%i!"
        )

        set "code=!errorlevel!"
        echo   Код завершения: !code! >> "%LOG%"
        if "!code!"=="0" (
            set /a installed+=1
        ) else if "!code!"=="3010" (
            set /a installed+=1
        ) else (
            set /a insterr+=1
        )
    )
)

echo. >> "%LOG%"
echo === Установка по пресету завершена: %date% %time% === >> "%LOG%"
echo Скачано: !dlok!, ошибок скачивания: !dlerr! >> "%LOG%"
echo Установлено: !installed!, проблемных установок: !insterr! >> "%LOG%"
echo Не найдено: !missing! >> "%LOG%"

echo [%time%] Пресет "!profilename!" - установлено !installed!, скачано !dlok!, не найдено !missing! ^(лог: !LOG:*\=!^) >> "%SESSIONLOG%"

echo.
echo Готово. Установлено: !installed!, проблемных: !insterr!, не найдено: !missing!
echo Лог: %LOG%
pause
endlocal
exit /b


:: ============================================
:: Перезапуск от имени администратора
:: ============================================
:elevate
call :check_admin
if "!ADMINSTATUS!"=="Да" (
    echo Скрипт уже запущен от имени администратора.
    pause
    exit /b
)
echo Будет показан запрос UAC. Текущее окно закроется после подтверждения.
choice /c YN /m "Перезапустить от имени администратора"
if !errorlevel! neq 1 (
    echo Отменено.
    pause
    exit /b
)
powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -WorkingDirectory '%~dp0' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if !errorlevel! equ 0 (
    set "QUIT=1"
) else (
    echo Запрос UAC отклонён или перезапуск не удался.
    pause
)
exit /b


:: ============================================
:: О программе
:: ============================================
:about
cls
echo ============================================
echo   Progs - версия !VERSION!
echo ============================================
echo   Портативный набор для установки программ,
echo   чистки реестра и работы с пресетами.
echo.
echo   История версий:
echo.
echo   2.1  Перезапуск от администратора из меню,
echo        экран О программе
echo   2.0  Очистка реестра по списку registry.txt,
echo        установка по пресетам, отчёт по сессии,
echo        проверка прав администратора и интернета
echo   1.5  Добавление ссылок из меню, логи по типам,
echo        лог удаления
echo   1.0  Скачивание, установка, удаление программ,
echo        открытие ссылок и txt файлов
echo ============================================
pause
exit /b
