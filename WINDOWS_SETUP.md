# Windows Setup Guide

This guide helps Windows users successfully deploy the Snowflake File Processing Pipeline.

## Prerequisites

### 1. Install Git for Windows (includes Git Bash)

Download and install from: https://git-scm.com/download/win

**Important**: Git Bash is **required** - Command Prompt and PowerShell are not supported.

### 2. Install Python

Download from: https://www.python.org/downloads/

**Important**: During installation, check the box "Add Python to PATH"

### 3. Install Snowflake CLI

Open **Git Bash** and run:

```bash
pip install snowflake-cli-labs
```

Configure your connection:

```bash
snow connection add
```

## Running the Deployment

### Step 1: Open Git Bash

- **Right-click** in your project folder
- Select **"Git Bash Here"**
- Or open Git Bash and navigate: `cd /c/path/to/file_processing_pipeline`

### Step 2: Make Scripts Executable

```bash
chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh
```

### Step 3: Run Deployment

```bash
./deploy.sh
```

## Common Windows Issues & Solutions

### Issue 1: Character Encoding Error

**Error Message:**
```
'charmap' codec can't decode byte 0x90 in position 1207: character maps to <undefined>
```

**Cause:**
The SQL files contain Unicode box-drawing characters (like `─`, `│`, `┌`, etc.) in comments that Windows Python can't decode with the default charmap encoding.

**Solution:**
The deployment scripts now **automatically** handle this on Windows by:
1. Detecting Windows environment
2. Creating temporary ASCII-safe versions of SQL files
3. Replacing Unicode characters with ASCII equivalents
4. Cleaning up temporary files after execution

**No action needed** - just run the deployment normally:

```bash
./deploy.sh
```

The scripts will automatically convert the files for Windows compatibility.

### Issue 2: Line Ending Issues

**Error Message:**
```
^M: bad interpreter
```

**Solution:**
Configure Git to use Unix line endings:

```bash
git config --global core.autocrlf input
git config --global core.eol lf

# Re-clone the repository or reset line endings
git rm --cached -r .
git reset --hard
```

### Issue 3: Permission Denied

**Error Message:**
```
Permission denied: ./deploy.sh
```

**Solution:**
```bash
chmod +x deploy.sh deploy_bronze.sh deploy_silver.sh undeploy.sh
```

### Issue 4: Python Not Found

**Error Message:**
```
Python is not installed or not in PATH
```

**Solution:**
1. Reinstall Python and check "Add Python to PATH"
2. Or manually add Python to PATH:
   - Search "Environment Variables" in Windows
   - Edit "Path" variable
   - Add: `C:\Users\YourUsername\AppData\Local\Programs\Python\Python3xx`
3. Restart Git Bash after changing PATH

### Issue 5: snow Command Not Found

**Error Message:**
```
snow: command not found
```

**Solution:**
```bash
# Install Snowflake CLI
pip install snowflake-cli-labs

# If pip is not found, use:
python -m pip install snowflake-cli-labs

# Verify installation
snow --version
```

## Verifying Your Setup

Run this test to verify everything is configured correctly:

```bash
# Check OS detection
uname -s
# Should show: MINGW64_NT or similar

# Check Python
python --version
# Should show: Python 3.x.x

# Check Snowflake CLI
snow --version
# Should show version number

# Check encoding (should be set automatically)
echo $PYTHONIOENCODING
# Should show: utf-8 (after running deployment script)
```

## Tips for Windows Users

1. **Always use Git Bash** - Not Command Prompt or PowerShell
2. **Use forward slashes** in paths: `/c/Users/...` not `C:\Users\...`
3. **Watch for line endings** - Keep files in LF format, not CRLF
4. **UTF-8 encoding** - The scripts now handle this automatically
5. **Run as regular user** - Administrator privileges not required

## Getting Help

If you encounter issues not covered here:

1. Check the main [README.md](README.md) troubleshooting section
2. Verify you're using Git Bash (not Command Prompt/PowerShell)
3. Ensure all prerequisites are installed correctly
4. Check that your Snowflake connection is configured: `snow connection test`

## Quick Reference

| Task | Command |
|------|---------|
| Open Git Bash | Right-click folder → "Git Bash Here" |
| Navigate to project | `cd /c/path/to/project` |
| Make executable | `chmod +x *.sh` |
| Deploy everything | `./deploy.sh` |
| Deploy Bronze only | `./deploy_bronze.sh` |
| Deploy Silver only | `./deploy_silver.sh` |
| Remove everything | `./undeploy.sh` |
| Test connection | `snow connection test` |
| Check encoding | `echo $PYTHONIOENCODING` |

## Success Checklist

Before running deployment, verify:

- [ ] Git Bash is installed and open (not Command Prompt/PowerShell)
- [ ] Python is installed and in PATH
- [ ] Snowflake CLI is installed (`snow --version` works)
- [ ] Snowflake connection is configured (`snow connection test` succeeds)
- [ ] You have SYSADMIN and SECURITYADMIN roles in Snowflake
- [ ] Scripts are executable (`chmod +x *.sh`)
- [ ] You're in the project directory

Once all items are checked, run `./deploy.sh` and the deployment should succeed!
