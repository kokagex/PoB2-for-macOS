# PoB2macOS Installation Guide

**Project**: PRJ-003 PoB2macOS
**Version**: 1.0.0
**Date**: 2026-01-30

---

## Installation Methods

### Method 1: DMG Installer (Recommended)

**For**: End users who want the simplest installation

**Steps:**

1. **Download the DMG**
   ```bash
   # Location: /Users/kokage/national-operations/pob2macos/PoB2macOS-v1.0.0.dmg
   ```

2. **Mount the Disk Image**
   - Double-click `PoB2macOS-v1.0.0.dmg`
   - Or use Terminal:
     ```bash
     open PoB2macOS-v1.0.0.dmg
     ```

3. **Install the Application**
   - Drag `PoB2macOS.app` to your `/Applications` folder
   - Or copy to any preferred location

4. **Launch**
   - Open from Applications folder
   - Or use Spotlight (Cmd+Space, type "PoB2")
   - Or from Terminal:
     ```bash
     open /Applications/PoB2macOS.app
     ```

5. **First Launch** (macOS Security)
   - If blocked by Gatekeeper: Right-click → Open → Confirm
   - Or: System Preferences → Security & Privacy → "Open Anyway"

---

### Method 2: Application Bundle (Advanced)

**For**: Users who have the .app bundle directly

**Steps:**

1. **Copy the Bundle**
   ```bash
   cp -r PoB2macOS.app /Applications/
   ```

2. **Set Permissions**
   ```bash
   chmod +x /Applications/PoB2macOS.app/Contents/MacOS/PoB2macOS
   ```

3. **Launch**
   ```bash
   open /Applications/PoB2macOS.app
   ```

---

### Method 3: Build from Source (Developers)

**For**: Developers, contributors, or users who want to customize

#### Prerequisites

**Install Homebrew** (if not installed):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Install Dependencies:**
```bash
brew install lua glfw freetype zstd cmake git
```

#### Build Steps

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd pob2macos
   ```

2. **Configure Build**
   ```bash
   mkdir build && cd build
   cmake -DCMAKE_BUILD_TYPE=Release ..
   ```

3. **Compile**
   ```bash
   make -j4
   ```
   - `-j4`: Use 4 parallel jobs (adjust based on your CPU cores)

4. **Verify Build**
   ```bash
   ls -lh PoB2macOS
   # Should show ~231KB executable
   ```

5. **Run**
   ```bash
   ./PoB2macOS
   ```

#### Optional: Install System-Wide

```bash
sudo make install
# Installs to /usr/local/bin
```

---

## Advanced Build Configurations

### Debug Build (with symbols)

```bash
mkdir build_debug && cd build_debug
cmake -DCMAKE_BUILD_TYPE=Debug ..
make -j4
```

**Use case**: Development, debugging with lldb/gdb

### ThreadSanitizer Build (race detection)

```bash
mkdir build_tsan && cd build_tsan
cmake -DCMAKE_BUILD_TYPE=Debug -DENABLE_TSAN=ON ..
make -j4
```

**Use case**: Finding data races, thread safety testing

**Run with TSAN:**
```bash
./PoB2macOS
# Check stderr for TSAN warnings
```

### Valgrind Build (memory leak detection)

```bash
mkdir build_valgrind && cd build_valgrind
cmake -DCMAKE_BUILD_TYPE=Debug -DENABLE_VALGRIND=ON ..
make -j4
```

**Use case**: Memory leak detection, profiling

**Run with Valgrind:**
```bash
valgrind --leak-check=full --show-leak-kinds=all ./PoB2macOS
```

---

## Verification

### Check Installation

```bash
# Verify app bundle exists
ls -ld /Applications/PoB2macOS.app

# Verify executable
ls -lh /Applications/PoB2macOS.app/Contents/MacOS/PoB2macOS

# Check Info.plist
plutil -p /Applications/PoB2macOS.app/Contents/Info.plist
```

### Test Launch

```bash
# Launch and check for errors
/Applications/PoB2macOS.app/Contents/MacOS/PoB2macOS 2>&1 | tee launch.log
```

**Expected Output:**
- Window opens
- Graphics initialize
- (Note: Black screen issue under investigation - see Troubleshooting)

---

## Troubleshooting

### Issue: "App is damaged and can't be opened"

**Cause**: Gatekeeper security on unsigned app

**Solution 1** (Temporary):
```bash
xattr -cr /Applications/PoB2macOS.app
```

**Solution 2** (Permanent):
```bash
spctl --add /Applications/PoB2macOS.app
```

### Issue: "dyld: Library not loaded"

**Cause**: Missing shared libraries

**Check dependencies:**
```bash
otool -L /Applications/PoB2macOS.app/Contents/MacOS/PoB2macOS
```

**Fix**: Install missing libraries via Homebrew
```bash
brew install lua glfw freetype zstd
```

### Issue: Black Screen on Launch

**Status**: Known issue under investigation

**Quick Diagnostics:**

1. **Check Console for errors:**
   - Open Console.app
   - Filter for "PoB2macOS"
   - Look for OpenGL, shader, or resource errors

2. **Verify OpenGL support:**
   ```bash
   system_profiler SPDisplaysDataType | grep OpenGL
   ```
   - Should show OpenGL 3.3 or higher

3. **Debug View Hierarchy:**
   - Run from Xcode
   - Debug → View Debugging → Capture View Hierarchy
   - Check view sizes and positions

**Detailed Guide**: See `gemini_iken.md` in project memory

### Issue: Build Fails

**Common causes and solutions:**

1. **Missing CMake:**
   ```bash
   brew install cmake
   ```

2. **Old macOS SDK:**
   ```bash
   xcode-select --install
   ```

3. **Lua not found:**
   ```bash
   brew install lua
   # Verify
   pkg-config --cflags lua
   ```

4. **GLFW not found:**
   ```bash
   brew install glfw
   ```

---

## Uninstallation

### Remove Application

```bash
rm -rf /Applications/PoB2macOS.app
```

### Remove Build Artifacts (if built from source)

```bash
cd pob2macos
rm -rf build build_debug build_tsan build_valgrind
```

### Remove Source Code

```bash
rm -rf ~/path/to/pob2macos
```

---

## System Requirements

### Minimum

- macOS 10.15 (Catalina)
- OpenGL 3.3 support
- 512MB RAM
- 100MB disk space

### Recommended

- macOS 11.0 (Big Sur) or later
- Apple Silicon (M1/M2) or Intel x86_64
- 1GB RAM
- 500MB disk space

### Dependencies

The following are included or dynamically linked:

- Lua 5.4.8
- GLFW 3.4.0
- FreeType 26.4.20
- libzstd 1.5.7
- macOS OpenGL framework

---

## Getting Help

### Documentation

- **Release Notes**: `PHASE17_RELEASE_NOTES.md`
- **Testing Report**: `MERCHANT_PHASE17_TESTING_REPORT.md`
- **Security Report**: `PALADIN_PHASE17_SECURITY_REPORT.md`

### Diagnostics

- **Black Screen**: `gemini_iken.md`
- **Build Issues**: Check CMake output
- **Runtime Errors**: Check Console.app

### Support

- GitHub Issues: [repository-url]/issues
- Documentation: `memory/PRJ-003_pob2macos/`

---

## For Developers

### Running Tests

```bash
cd build
ctest --verbose
```

### Individual Test Suites

```bash
./mvp_test                    # MVP functionality
./test_cleanup_handler        # Lua cleanup
./test_resource_tracker       # Resource tracking
./test_checkpoint_shutdown    # Graceful shutdown
```

### Test with ThreadSanitizer

```bash
cd build_tsan
./mvp_test 2>&1 | grep "WARNING: ThreadSanitizer"
# No output = no race conditions ✅
```

### Test with Valgrind

```bash
cd build_valgrind
valgrind --leak-check=full --show-leak-kinds=all ./mvp_test
# Look for "0 bytes in 0 blocks" ✅
```

---

## Upgrading

### From Previous Version

1. **Backup settings** (if any):
   ```bash
   cp -r ~/Library/Application\ Support/PoB2macOS ~/Desktop/PoB2macOS-backup
   ```

2. **Remove old version**:
   ```bash
   rm -rf /Applications/PoB2macOS.app
   ```

3. **Install new version** (follow installation steps above)

4. **Restore settings** (if applicable):
   ```bash
   cp -r ~/Desktop/PoB2macOS-backup/* ~/Library/Application\ Support/PoB2macOS/
   ```

---

## FAQ

**Q: Why is the screen black when I launch?**
A: This is a known issue under investigation. See "Black Screen on Launch" in Troubleshooting.

**Q: Do I need to install dependencies?**
A: No, if using the DMG installer. Yes, if building from source.

**Q: Is Apple Silicon (M1/M2) supported?**
A: Yes, the app is universal binary compatible.

**Q: How do I enable debug logging?**
A: Set environment variable:
```bash
DEBUG=1 /Applications/PoB2macOS.app/Contents/MacOS/PoB2macOS
```

**Q: Can I run multiple instances?**
A: Yes, the app supports multiple instances.

---

**Installation support**: See documentation or file an issue
**Last updated**: 2026-01-30
**Project**: PRJ-003 PoB2macOS Phase 17
