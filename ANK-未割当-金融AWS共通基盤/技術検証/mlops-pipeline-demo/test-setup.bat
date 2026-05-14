@echo off
REM MLOps Pipeline Demo - Setup Test Script (Windows)
REM This script verifies that all components are working correctly

echo ========================================
echo MLOps Pipeline Demo - Setup Test
echo ========================================
echo.

set tests_passed=0
set tests_failed=0

echo Testing: Docker is running...
docker info >nul 2>&1
if errorlevel 1 (
    echo FAIL: Docker is not running
    set /a tests_failed+=1
) else (
    echo PASS: Docker is running
    set /a tests_passed+=1
)

echo Testing: Docker Compose is available...
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo FAIL: Docker Compose not found
    set /a tests_failed+=1
) else (
    echo PASS: Docker Compose is available
    set /a tests_passed+=1
)

echo Testing: Project structure exists...
if exist docker-compose.yml (
    if exist Dockerfile (
        if exist pipeline (
            echo PASS: Project structure exists
            set /a tests_passed+=1
        ) else (
            echo FAIL: Pipeline directory missing
            set /a tests_failed+=1
        )
    ) else (
        echo FAIL: Dockerfile missing
        set /a tests_failed+=1
    )
) else (
    echo FAIL: docker-compose.yml missing
    set /a tests_failed+=1
)

echo Testing: Pipeline files exist...
if exist pipeline\train.py (
    if exist pipeline\evaluate.py (
        if exist pipeline\preprocess.py (
            echo PASS: Pipeline files exist
            set /a tests_passed+=1
        ) else (
            echo FAIL: preprocess.py missing
            set /a tests_failed+=1
        )
    ) else (
        echo FAIL: evaluate.py missing
        set /a tests_failed+=1
    )
) else (
    echo FAIL: train.py missing
    set /a tests_failed+=1
)

echo Testing: Sample data exists...
if exist data\sample_data.csv (
    echo PASS: Sample data exists
    set /a tests_passed+=1
) else (
    echo FAIL: sample_data.csv missing
    set /a tests_failed+=1
)

echo Testing: Requirements file exists...
if exist pipeline\requirements.txt (
    echo PASS: Requirements file exists
    set /a tests_passed+=1
) else (
    echo FAIL: requirements.txt missing
    set /a tests_failed+=1
)

echo Testing: Jupyter notebook exists...
if exist notebooks\exploration.ipynb (
    echo PASS: Jupyter notebook exists
    set /a tests_passed+=1
) else (
    echo FAIL: exploration.ipynb missing
    set /a tests_failed+=1
)

echo.
echo ========================================
echo Test Summary
echo ========================================
echo Tests Passed: %tests_passed%
echo Tests Failed: %tests_failed%
echo.

if %tests_failed%==0 (
    echo All tests passed! Setup is correct.
    echo.
    echo You can now run the pipeline with:
    echo   run-pipeline.bat
) else (
    echo Some tests failed. Please check the errors above.
    echo.
    echo Common fixes:
    echo   1. Ensure Docker Desktop is running
    echo   2. Check Docker has enough memory (4GB minimum)
    echo   3. Rebuild containers: docker-compose build --no-cache
)

pause
