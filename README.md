# Blastframe Sequence Auditor

A Premiere Pro CEP (Common Extensibility Platform) panel that audits sequences and generates structured markdown reports of all clips across all tracks.

## Overview

The Sequence Auditor is designed to help video editors quickly analyze and document their Premiere Pro sequences. It extracts clip information from all video and audio tracks, organizing them into a structured markdown format that can be used for project documentation, collaboration, or further analysis.

## Features

- **Multi-Track Analysis**: Audits clips from ALL video and audio tracks (not just the first track)
- **Markdown Export**: Generates clean, structured markdown output
- **Copy to Clipboard**: One-click copying of the generated markdown
- **Text Sequence Creation**: Convert markdown content back into Premiere Pro text clips
- **Track Information**: Shows which track each clip originates from
- **Frame-Accurate Timing**: Precise start/end frame and duration information

## Important Limitation: Adobe Premiere Pro Text Content Access

⚠️ **Adobe Premiere Pro's ExtendScript API does not expose the actual text content of Graphics/Title clips.**

This is a significant limitation of Adobe's API, not a bug in this extension. Here's what this means:

### What We Can Access:
- ✅ Clip names
- ✅ Clip timing (start/end frames, duration)
- ✅ Track information
- ✅ Basic clip properties

### What We Cannot Access:
- ❌ Text content inside Essential Graphics clips (.mogrt files)
- ❌ Text content in Legacy Title clips
- ❌ Text properties and values from Motion Graphics Templates
- ❌ Source text from After Effects compositions

### Workaround Solution:
To get meaningful text information in your audit:
1. **Name your Graphics clips** with the text content you want to appear in the audit
2. The extension will use the **clip name** as the text value in the markdown output
3. For example: Rename a Graphics clip from "Graphic" to "Welcome to Our Story"

This limitation exists because Adobe's ExtendScript API for Premiere Pro doesn't provide read access to the internal text properties of graphics clips, even though these properties are visible and editable in the Essential Graphics panel.

## Installation

### Prerequisites
- Adobe Premiere Pro (2019 or later recommended)
- macOS or Windows

### Method 1: File System Installation (Development)

1. **Enable Debug Mode** (allows unsigned panels):
   ```bash
   # macOS
   defaults write com.adobe.CSXS.11 PlayerDebugMode 1
   defaults write com.adobe.CSXS.10 PlayerDebugMode 1
   defaults write com.adobe.CSXS.9 PlayerDebugMode 1
   
   # Windows (Command Prompt as Administrator)
   REG ADD HKCU\Software\Adobe\CSXS.11 /v PlayerDebugMode /t REG_SZ /d 1
   REG ADD HKCU\Software\Adobe\CSXS.10 /v PlayerDebugMode /t REG_SZ /d 1
   REG ADD HKCU\Software\Adobe\CSXS.9 /v PlayerDebugMode /t REG_SZ /d 1
   ```

2. **Download or Clone** this repository

3. **Copy to CEP Extensions Folder**:
   ```bash
   # macOS (per-user)
   ~/Library/Application Support/Adobe/CEP/extensions/com.blastframe.panel/
   
   # macOS (system-wide)
   /Library/Application Support/Adobe/CEP/extensions/com.blastframe.panel/
   
   # Windows (per-user)
   %APPDATA%\Adobe\CEP\extensions\com.blastframe.panel\
   
   # Windows (system-wide)
   %PROGRAMFILES(X86)%\Common Files\Adobe\CEP\extensions\com.blastframe.panel\
   ```

4. **Restart Premiere Pro**

5. **Access the Panel**: Window → Extensions (Legacy) → Blastframe Sequence Auditor

### Method 2: ZXP Installation (Distribution)

1. Build a ZXP package using the included build script
2. Install using [ZXP Installer](https://aescripts.com/learn/zxp-installer/) or similar tool

## Usage

### Basic Workflow

1. **Open a Sequence** in Premiere Pro's timeline
2. **Launch the Panel**: Window → Extensions (Legacy) → Blastframe Sequence Auditor
3. **Generate Audit**: Click "Generate Markdown Audit"
4. **Copy Results**: Click "Copy Markdown" to copy to clipboard
5. **Create Text Sequence** (Optional): Click "Create Text Sequence" to convert markdown back into Premiere clips

### Generated Markdown Structure

The audit generates markdown organized into acts/sections with the following information for each clip:

```markdown
# CYBERNETIC LIST

---

## THE RACE

- **Start:** Frame 0
- **End:** Frame 449
- **Duration:** 449 frames (18.71 seconds)

**1. Opening Title**
  - **Start:** Frame 0
  - **End:** Frame 72
  - **Duration:** 72 frames (3.00 seconds)
  - **Track:** Video Track 1

**2. Character Introduction**
  - **Start:** Frame 72
  - **End:** Frame 200
  - **Duration:** 128 frames (5.33 seconds)
  - **Track:** Video Track 2
```

### Text Sequence Creation

The "Create Text Sequence" feature allows you to:
1. Convert any markdown content back into Premiere Pro clips
2. Specify duration in frames (e.g., "24" for 1 second at 24fps)
3. Creates color matte placeholders with text content stored in clip names
4. Places clips sequentially in a new sequence

## Development

### Building from Source

1. **Install ZXPSignCmd** from Adobe's CEP Resources
2. **Configure paths** in `build_and_sign_zxp.sh`
3. **Run build script**:
   ```bash
   chmod +x build_and_sign_zxp.sh
   ./build_and_sign_zxp.sh
   ```

### Project Structure

```
com.blastframe.panel/
├── CSXS/
│   └── manifest.xml          # Extension manifest
├── js/
│   └── main.js              # Client-side JavaScript
├── jsx/
│   └── hostscript.jsx       # ExtendScript for Premiere Pro
├── index.html               # Panel UI
├── CSInterface.js           # Adobe CEP interface library
├── build_and_sign_zxp.sh   # Build script
└── README.md               # This file
```

### API Limitations

This extension works within the constraints of Adobe's ExtendScript API for Premiere Pro:

- **Text Content**: Cannot access actual text inside Graphics clips (API limitation)
- **Complex Properties**: Limited access to advanced clip properties
- **Performance**: ExtendScript can be slow with large sequences
- **Version Compatibility**: Some features may vary between Premiere Pro versions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with multiple Premiere Pro versions
5. Submit a pull request

## Troubleshooting

### Panel Doesn't Appear
- Ensure PlayerDebugMode is enabled
- Restart Premiere Pro completely
- Check CEP logs: `~/Library/Logs/CSXS/` (macOS) or `%TEMP%` (Windows)

### No Clips Found
- Ensure a sequence is active in the timeline
- Check that clips have names (rename "Graphic" clips to meaningful names)
- Verify clips aren't on locked or hidden tracks

### Script Errors
- Open DevTools: Navigate to `http://localhost:8088` in Chrome (when panel is open)
- Check browser console for JavaScript errors
- Review CEP logs for ExtendScript errors

## License

This project is open source. Please check the repository for license details.

## Credits

Developed by Blastframe for the Adobe Premiere Pro community.

---

**Note**: This extension is not affiliated with Adobe Inc. Adobe Premiere Pro is a trademark of Adobe Inc.