@ECHO OFF

SETLOCAL ENABLEDELAYEDEXPANSION

@REM Determine command to run java
IF DEFINED JAVA_HOME GOTO findJavaFromJavaHome

SET JAVACMD=java.exe
%JAVACMD% -version >NUL 2>&1
if "%ERRORLEVEL%" == "0" GOTO init

ECHO.
ECHO. ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
ECHO.
ECHO Please set the JAVA_HOME variable in your environment to match the
ECHO location of your Java installation.

GOTO fail

:findJavaFromJavaHome
SET JAVA_HOME=%JAVA_HOME:"=%
SET JAVACMD=%JAVA_HOME%/bin/java.exe

IF EXIST "%JAVACMD%" GOTO init

ECHO.
ECHO. ERROR: JAVA_HOME is set to an invalid directory: %JAVA_HOME%
ECHO.
ECHO Please set the JAVA_HOME variable in your environment to match the
ECHO location of your Java installation.

GOTO fail

:init

@REM Determine java options
IF "%GRAIN_OPTS%" == "" set GRAIN_OPTS=-server -Xmx256M -Xms32M -XX:PermSize=32m -XX:MaxPermSize=128m
SET JAVA_OPTS=%GRAIN_OPTS% %JAVA_OPTS%

@REM Get target Grain version

SET APP_PROPS=application.properties

IF NOT EXIST "%APP_PROPS%" (
    ECHO Error: %APP_PROPS% not found
    GOTO fail
)

FOR /f "tokens=1*delims== " %%a IN (%APP_PROPS%) DO (
    IF /i "%%a"=="grain.version" (
        SET "GRAIN_VERSION=%%b"
    )
)

IF "%GRAIN_VERSION%" == "" (
    ECHO Unable to determine Grain version from %APP_PROPS%
    GOTO fail
)

@REM Check if site deps exists for current Grain version
SET SITE_DEPS=.site-%GRAIN_VERSION%.dep

IF NOT EXIST "%SITE_DEPS%" (
    @REM Site deps don't exist - generate them
    CALL gradlew.bat gendeps
    IF NOT "%ERRORLEVEL%"=="0" GOTO fail
)

CALL :validateAndLaunch %*
if "%ERRORLEVEL%"=="2" (
    @REM Site deps invalid - regenerate them
    CALL gradlew.bat gendeps
    CALL :validateAndLaunch %*
)
EXIT /B %ERRORLEVEL% 

:fail
EXIT /B 1

:validateAndLaunch
@REM Get Grain JAR from site deps

FOR /F ^"usebackq^ eol^=^

^ delims^=^" %%a in (%SITE_DEPS%) do (
   SET GRAIN_JAR=%%a
   GOTO _validate1
)
:_validate1

IF NOT EXIST "%GRAIN_JAR%" (
    @REM Grain Jar doesn't exist - regenerate site deps and recompute Grain Jar
    CALL gradlew.bat gendeps
    IF NOT "%ERRORLEVEL%"=="0" GOTO fail
    FOR /f %%a in (%SITE_DEPS%) do (
        SET GRAIN_JAR=%%a
        GOTO _validate2
    )
)
:_validate2

@REM Check if site deps are valid
"%JAVACMD%" %JAVA_OPTS% -cp "%GRAIN_JAR%" com.sysgears.grain.SiteLauncher %GRAIN_VERSION% -- %*
GOTO :EOF

:mainEnd
ENDLOCAL
