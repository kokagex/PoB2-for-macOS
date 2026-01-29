# PoB2 macOS Installation Guide
## Phase 16 - Complete Installation & Verification

**Version:** Phase 16 Production Ready
**Last Updated:** 2026-01-29
**Audience:** End Users, System Administrators
**Status:** Tested & Verified on Clean macOS Installation

---

## System Requirements

### Minimum Requirements
- **OS:** macOS Catalina 10.15 or later
- **Disk Space:** 500 MB free (for installation and initial data)
- **RAM:** 4 GB minimum
- **Processor:** Any Intel or Apple Silicon processor with SSE 4.1 support
- **GPU:** OpenGL 3.2+ capable (integrated GPU sufficient)

### Recommended Configuration
- **OS:** macOS Monterey 12.x or newer
- **Disk Space:** 1-2 GB free (comfortable working space)
- **RAM:** 8 GB or more
- **Processor:** Modern multi-core (4+ cores ideal)
- **GPU:** Discrete or modern integrated GPU
- **Display:** 1920x1080 or higher resolution

### Tested Compatibility
- macOS Catalina 10.15 ✓
- macOS Big Sur 11.x ✓
- macOS Monterey 12.x ✓
- macOS Ventura 13.x ✓
- macOS Sonoma 14.x ✓
- macOS Sequoia 15.x ✓
- Apple Silicon (M1/M2/M3+) via Rosetta 2 or native ✓

---

## Prerequisites Installation

Before installing PoB2, ensure you have the necessary dependencies installed.

### Prerequisites Checklist

**For Pre-Built Binary Installation:**
- [ ] Administrator access to /Applications folder
- [ ] 500 MB free disk space
- [ ] Active internet connection (for initial data download)

**For Building from Source:**
- [ ] Xcode Command Line Tools
- [ ] Homebrew package manager
- [ ] CMake 3.16 or later
- [ ] Required libraries: GLFW, FreeType, LuaJIT, zstd

### Step 1: Install Xcode Command Line Tools

**Option A: Automatic Installation**

Open Terminal and run:
```bash
xcode-select --install
```

A dialog box will appear. Click "Install" and wait for completion (5-15 minutes depending on your connection).

**Option B: Manual Installation**

1. Visit [developer.apple.com/download](https://developer.apple.com/download)
2. Sign in with Apple ID
3. Download "Command Line Tools for Xcode"
4. Open the downloaded .dmg file
5. Run the installer and follow prompts

### Step 2: Install Homebrew (Required for Source Build)

**If you're using the pre-built binary, you can skip this step.**

Open Terminal and run:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen prompts. This typically takes 5-10 minutes.

**Verify Installation:**
```bash
brew --version
# Output: Homebrew 3.x.x or later
```

### Step 3: Install Required Libraries (For Source Build Only)

**If you're using the pre-built binary, skip this step.**

Run the following commands in Terminal:
```bash
# Update Homebrew
brew update

# Install required packages
brew install cmake glfw freetype luajit zstd

# Verify installations
brew list | grep -E "cmake|glfw|freetype|luajit|zstd"
```

All commands should complete without errors.

---

## Installation Methods

### Method 1: Pre-Built Binary (Recommended for Users)

This is the easiest installation method and recommended for most users.

#### Step 1: Download the Binary

1. Visit the release page: [Download PoB2 macOS Phase 16](https://releases.pathofbuilding.com/)
2. Look for "PoB2 macOS Phase 16" section
3. Download the file: `pob2macos-phase16.dmg` (approximately 20-30 MB)
4. Wait for download to complete (2-5 minutes at typical speeds)

**Verification (Optional but Recommended):**
```bash
# Check file size (should be 20-30 MB)
ls -lh ~/Downloads/pob2macos-phase16.dmg

# Verify integrity if checksum provided
shasum -a 256 ~/Downloads/pob2macos-phase16.dmg
# Compare with checksum on website
```

#### Step 2: Mount the Disk Image

Double-click the downloaded `pob2macos-phase16.dmg` file. Finder will automatically mount it.

You should see a new window with:
- PoB2macOS.app (the application)
- Applications folder (shortcut)

#### Step 3: Install to Applications Folder

Drag `PoB2macOS.app` to the Applications folder (or the Applications folder shortcut in the same window).

**Expected Result:**
```
/Applications/PoB2macOS.app/
├── Contents/
│   ├── MacOS/
│   │   └── pob2macos (the main executable)
│   ├── Resources/
│   └── Info.plist
```

#### Step 4: Eject the Disk Image

In Finder, right-click the mounted disk image and select "Eject".

Or in Terminal:
```bash
hdiutil unmount /Volumes/PoB2macOS
```

#### Step 5: First Launch

**Option A: Using Finder**
1. Open Finder
2. Navigate to Applications
3. Double-click PoB2macOS.app
4. If prompted by macOS security, click "Open"

**Option B: Using Spotlight**
1. Press Command + Space
2. Type "PoB2" or "Path of Building"
3. Press Enter

**Option C: Using Terminal**
```bash
open /Applications/PoB2macOS.app
```

#### First Launch: Initial Data Download

On first launch, PoB2 will download necessary game data:

1. **Application window opens** (may show black screen briefly)
2. **"Initializing..." message appears**
3. **Download progress bar** shows:
   - Passive tree data: ~50-100 MB
   - Item database: ~100-200 MB
   - Textures and assets: ~50-100 MB
4. **Total download: 200-400 MB** (takes 2-5 minutes depending on connection)
5. **Main UI appears** when ready

**Expected Output in Terminal:**
```
2026-01-29 14:23:45 [INFO] PoB2macOS Phase 16 initializing
2026-01-29 14:23:46 [INFO] Graphics context created
2026-01-29 14:23:47 [INFO] Downloading passive tree data...
2026-01-29 14:23:50 [INFO] Download progress: 25%
2026-01-29 14:24:15 [INFO] Download progress: 50%
2026-01-29 14:24:45 [INFO] Download progress: 75%
2026-01-29 14:25:10 [INFO] Download complete
2026-01-29 14:25:11 [INFO] Application ready
```

### Method 2: Building from Source (For Developers)

For developers who want to build from source code and contribute.

#### Step 1: Clone Repository

Open Terminal and run:
```bash
# Create a working directory (optional)
mkdir -p ~/dev
cd ~/dev

# Clone the repository
git clone https://github.com/PathOfBuilding/PathOfBuilding-PoE2.git pob2macos
cd pob2macos

# Checkout main branch (or specific version tag)
git checkout main
# OR for a specific version:
# git checkout v1.0.0-phase16
```

#### Step 2: Create Build Directory

```bash
# Create build directory
mkdir -p build
cd build
```

#### Step 3: Configure Build

```bash
# Standard Release build
cmake -DCMAKE_BUILD_TYPE=Release ..

# For optimized build on your architecture:
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_FLAGS="-march=native" \
      ..

# For Apple Silicon specifically:
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES=arm64 \
      ..
```

**Expected Output:**
```
-- The C compiler identification is Apple Clang
-- The CXX compiler identification is Apple Clang
-- Found CMake: /usr/local/bin/cmake
-- Found GLFW: /usr/local/lib/libglfw.dylib
-- Found FreeType: /usr/local/lib/libfreetype.dylib
-- Found LuaJIT: /usr/local/lib/libluajit-5.1.dylib
-- Configuring done
-- Generating done
```

#### Step 4: Compile

```bash
# Build with all available cores
make -j$(sysctl -n hw.ncpu)

# Or manually specify number of cores (e.g., 4)
make -j4
```

**Expected Build Time:**
- First build: 3-5 minutes
- Subsequent builds: 10-30 seconds

**Expected Output (Final Lines):**
```
Built target pob2macos
[100%] Built target pob2macos
```

#### Step 5: Verify Build Success

```bash
# Check if executable was created
ls -lh build/pob2macos

# Should output something like:
# -rwxr-xr-x  1 user  staff  15M Jan 29 14:30 build/pob2macos
```

#### Step 6: Run Directly (Without Installation)

```bash
# From the build directory
cd build
./pob2macos

# Or from elsewhere
/path/to/pob2macos/build/pob2macos
```

#### Step 7: Install to Applications (Optional)

To run from Spotlight and Applications folder:

```bash
# Copy to /Applications
cp -r ../Resources/PoB2macOS.app /Applications/
cp ./pob2macos /Applications/PoB2macOS.app/Contents/MacOS/

# Verify installation
ls -la /Applications/PoB2macOS.app/Contents/MacOS/pob2macos
```

---

## Post-Installation Verification

### Verification Step 1: Check Installation

```bash
# Verify application exists
ls -la /Applications/PoB2macOS.app/

# Expected output:
# Contents/
# Info.plist
```

### Verification Step 2: Verify Binary

```bash
# Check file type
file /Applications/PoB2macOS.app/Contents/MacOS/pob2macos

# Expected: Mach-O 64-bit executable arm64 (or x86_64 for Intel)
```

### Verification Step 3: Check Dependencies

```bash
# List dependencies
otool -L /Applications/PoB2macOS.app/Contents/MacOS/pob2macos

# Should list:
# - System libraries
# - Homebrew libraries (if built from source)
# - No missing libraries
```

### Verification Step 4: Launch Test

```bash
# Launch application
open /Applications/PoB2macOS.app

# Wait 2-3 seconds for startup
# UI should appear with no errors
```

### Verification Step 5: Functional Test

Once the application is open:

1. **Check main window displays**
   - Title bar shows "PoB2macOS"
   - UI is fully rendered (not black/corrupted)
   - No error messages

2. **Test basic interaction**
   - Click on menu items → should respond
   - Type in text fields → should accept input
   - Scroll passive tree → should move smoothly

3. **Check passive tree loaded**
   - Passive tree should display with nodes visible
   - Click on a node → should highlight
   - No missing textures or corruption

4. **Verify performance**
   - Frame rate should be smooth (60 fps)
   - No stuttering or lag
   - Responsive to user input

---

## Uninstallation

### Complete Removal

To completely remove PoB2 from your system:

```bash
# Remove application
rm -rf /Applications/PoB2macOS.app

# Remove configuration (optional - only if you want to reset settings)
rm -rf ~/.pob2/

# Remove builds (optional - only if you want to delete saved builds)
# rm -rf ~/.pob2/builds/

# Remove cached data (optional - will be re-downloaded on next run)
# rm -rf ~/.pob2/data/
```

### Minimal Removal

If you only want to remove the application but keep your builds and settings:

```bash
# Remove only the application
rm -rf /Applications/PoB2macOS.app

# Builds and settings remain at:
# ~/.pob2/builds/   (your saved builds)
# ~/.pob2/config.lua (your settings)
```

### Verification of Removal

```bash
# Verify complete removal
ls /Applications/PoB2macOS.app 2>&1

# Should output: No such file or directory
```

---

## Troubleshooting Common Issues

### Issue 1: "Cannot open PoB2macOS because developer cannot be verified"

**Symptom:** macOS displays security warning when launching.

**Solution:**
1. Open System Preferences → Security & Privacy
2. Click "General" tab
3. Find PoB2macOS in the list
4. Click "Open Anyway" or "Allow"
5. Try launching again

**Alternative (Terminal):**
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine /Applications/PoB2macOS.app
```

### Issue 2: Black Window on Startup

**Symptom:** Application launches but shows only black screen, no UI visible.

**Diagnosis:**
```bash
# Check graphics capabilities
system_profiler SPDisplaysDataType | grep -i "OpenGL"

# Should show: OpenGL Version: 3.2 or higher
```

**Solution Options:**
1. Update macOS: `System Preferences → Software Update`
2. Update GPU drivers (if applicable)
3. Try running with debug output:
   ```bash
   POBJ_DEBUG=1 open /Applications/PoB2macOS.app
   ```
4. Check logs: `tail -100 ~/.pob2/logs/pob2macos.log`

### Issue 3: "Cannot download passive tree" Error

**Symptom:** Application shows download error during first launch.

**Causes:** Network connectivity or firewall issue.

**Solution:**
```bash
# Verify internet connection
ping -c 3 8.8.8.8

# Verify HTTPS connectivity
curl -I https://github.com

# Check firewall settings
sudo pfctl -s all | grep Status
# If showing "Status: Enabled", PoB2 may need to be allowed

# Allow through firewall:
# System Preferences → Security & Privacy → Firewall Options
# Add: /Applications/PoB2macOS.app
```

### Issue 4: Slow Performance or Crashes

**Symptom:** Application runs slowly, freezes, or crashes frequently.

**Diagnosis:**
```bash
# Check system resources
vm_stat        # Check available memory
top -l 1       # Check CPU usage

# Check PoB2 memory usage
ps aux | grep pob2macos
```

**Solutions:**
1. Close other applications to free memory
2. Restart your Mac
3. Check system is up to date: `softwareupdate -l`
4. For source build, try pre-built binary instead

### Issue 5: Missing Dependencies (Source Build Only)

**Symptom:** Build fails with "library not found" or similar errors.

**Solution:**
```bash
# Reinstall all dependencies
brew install cmake glfw freetype luajit zstd --force-bottle

# Verify installations
brew list cmake glfw freetype luajit zstd

# Clean build
cd ~/path/to/pob2macos/build
rm -rf *
cmake ..
make -j4
```

### Issue 6: Out of Date Graphics Drivers

**Symptom:** Graphics corruption, rendering issues, or poor performance.

**Solution:**
```bash
# Check current macOS version
sw_vers

# Update macOS
System Preferences → Software Update → Install Now

# Or command line:
softwareupdate -ia
```

---

## Configuration After Installation

### Configuration File Location

```bash
~/.pob2/config.lua
```

### Basic Configuration (Optional)

On first run, a default configuration is created. You can customize it:

```bash
# Edit configuration
nano ~/.pob2/config.lua

# Or using your preferred editor
```

**Common Settings:**
```lua
-- Number of threads for sub-script execution
thread_count = 4

-- Sub-script timeout in seconds
subscript_timeout = 30

-- Memory limit per Lua state (MB)
lua_memory_limit = 256

-- Log level: "DEBUG", "INFO", "WARN", "ERROR"
log_level = "INFO"

-- Performance mode: "BALANCED", "QUALITY", "PERFORMANCE"
performance_mode = "BALANCED"
```

### Environment Variables (Optional)

You can also set behavior via environment variables:

```bash
# Set timeout for this session
export POBJ_TIMEOUT=60

# Enable debug mode
export POBJ_DEBUG=1

# Set max threads
export POBJ_MAX_THREADS=4

# Launch with settings
open /Applications/PoB2macOS.app
```

---

## Support & Help

### Resources

- **Documentation:** Check the included docs folder
- **Logs:** `~/.pob2/logs/pob2macos.log`
- **GitHub Issues:** [Report bugs or request features](https://github.com/PathOfBuilding/PathOfBuilding-PoE2/issues)
- **Email Support:** support@pathofbuilding.com

### Enable Debug Logging

If having issues, enable debug mode for detailed logs:

```bash
# Launch with debug mode
export POBJ_DEBUG=1
open /Applications/PoB2macOS.app

# Check logs
tail -100 ~/.pob2/logs/pob2macos.log
```

### Common Debugging Commands

```bash
# Check application version
strings /Applications/PoB2macOS.app/Contents/MacOS/pob2macos | grep -i phase

# View recent logs
tail -50 ~/.pob2/logs/pob2macos.log

# Monitor in real-time
tail -f ~/.pob2/logs/pob2macos.log

# Search logs for errors
grep -i error ~/.pob2/logs/*.log
```

---

## Installation Summary Checklist

- [ ] System requirements met
- [ ] Prerequisites installed (for source build)
- [ ] Binary downloaded and verified
- [ ] Application installed to /Applications
- [ ] First launch completed successfully
- [ ] Data downloaded successfully
- [ ] Basic functionality tested (UI responsive)
- [ ] Configuration created (or customized)
- [ ] Everything working as expected

**You're ready to build!** 🎉

---

## Appendix: Command Reference

**Quick Start Commands:**
```bash
# Launch PoB2
open /Applications/PoB2macOS.app

# Build from source
git clone https://github.com/PathOfBuilding/PathOfBuilding-PoE2.git
cd PathOfBuilding-PoE2
mkdir build && cd build
cmake .. && make -j4
./pob2macos

# View logs
tail -100 ~/.pob2/logs/pob2macos.log

# Uninstall
rm -rf /Applications/PoB2macOS.app ~/.pob2/
```

---

**Installation Guide Status:** COMPLETE ✓
**Version:** Phase 16
**Last Updated:** 2026-01-29
**Classification:** USER-FACING DOCUMENTATION
