# Copilot Instructions for Shop_Chat SourcePawn Plugin

## Repository Overview

This repository contains a SourcePawn plugin for SourceMod that integrates with the Shop-Core system to provide purchasable chat customization features. The plugin allows players to buy:

- **Name Colors**: Custom colors for player names in chat
- **Text Colors**: Custom colors for chat message text  
- **Prefixes**: Custom prefixes/tags with colors that appear before player names

### Current Plugin Version
- **Version**: 2.2.6
- **Library**: "Shop_Chat" (registered for other plugins to depend on)
- **Authors**: R1KO, maxime1907
- **Compatibility**: SourceMod 1.11+ with new syntax

### Key Features
- Integration with Shop-Core plugin system
- Cookie-based persistence for player preferences
- Support for both file-based and free-form prefix systems
- Compatible with CustomChatColors (CCC) plugin
- Multi-language support structure
- Configurable pricing and duration system

## Technical Environment

### Core Dependencies
- **SourceMod**: 1.11.0+ (uses 1.11.0-git6917 in build)
- **SourcePawn Compiler**: Latest compatible with SM version
- **Build System**: SourceKnight 0.1

### Plugin Dependencies (Auto-managed by SourceKnight)
- **Shop-Core**: Primary shop system integration
- **MultiColors**: Enhanced color support for chat messages
- **CustomChatColors**: Optional integration for advanced color features

### Build Tools
- **SourceKnight**: Handles dependency management, compilation, and packaging
- **GitHub Actions**: Automated CI/CD pipeline for builds and releases

## Project Structure

```
addons/sourcemod/
├── scripting/
│   └── Shop_Chat.sp           # Main plugin source code
├── configs/
│   ├── chat_colors.cfg        # Available color definitions  
│   └── chat_prefix.cfg        # Available prefix options
sourceknight.yaml              # Build configuration and dependencies
.github/workflows/ci.yml       # CI/CD pipeline
```

**Note**: The config files are actually used from `configs/shop/` subdirectory when deployed.

## Code Style & Standards

### SourcePawn Conventions (Applied in this project)
- **Indentation**: Tabs (4 spaces equivalent)
- **Functions**: PascalCase (`OnPluginStart`, `MenuHandler_Color`)
- **Variables**: 
  - Local/parameters: camelCase (`iClient`, `hCvar`)
  - Globals: PascalCase with `g_` prefix (`g_hMenuColor`, `g_bUsed`)
- **Constants**: UPPER_CASE (`NAME_COLOR`, `DEFAULT_COLOR`)
- **Required pragmas**: `#pragma semicolon 1` and `#pragma newdecls required`

### Project-Specific Patterns
- **Handle Management**: Use `CheckCloseHandle()` function for safe cleanup
- **Menu Systems**: Separate menu handlers for different functionality
- **Cookie Storage**: Client preferences stored via SourceMod ClientPrefs
- **Color Formatting**: Uses `COLORTAG` constant with hex color codes
- **Configuration**: ConVars with proper callbacks for runtime updates

## Development Workflow

### Building the Plugin

1. **Using SourceKnight** (Recommended):
   ```bash
   # Install SourceKnight if not available
   # Build the plugin
   sourceknight build
   ```

2. **Dependencies**: Automatically managed by SourceKnight configuration

3. **Output**: Compiled `.smx` files placed in `addons/sourcemod/plugins`

### Configuration Files

#### chat_colors.cfg
- **Format**: SourceMod KeyValues structure
- **Structure**: `"Display Name" "HEXCODE"`
- **Purpose**: Defines available colors in selection menus
- **Location**: `addons/sourcemod/configs/shop/chat_colors.cfg`

#### chat_prefix.cfg  
- **Format**: Plain text, one prefix per line
- **Purpose**: Available prefixes when `sm_shop_chat_use_prefix_file` is enabled
- **Location**: `addons/sourcemod/configs/shop/chat_prefix.cfg`

### ConVar Configuration
Key configuration variables (auto-generated in `cfg/sourcemod/shop.cfg`):

```
// Name Color Settings
sm_shop_chat_name_price "1000"          // Purchase price
sm_shop_chat_name_sellprice "1000"      // Sell price (-1 to disable)
sm_shop_chat_name_duration "86400"      // Duration in seconds

// Text Color Settings  
sm_shop_chat_text_price "1000"
sm_shop_chat_text_sellprice "1000"
sm_shop_chat_text_duration "86400"

// Prefix Settings
sm_shop_chat_prefix_price "1000"
sm_shop_chat_prefix_sellprice "1000"
sm_shop_chat_prefix_duration "86400"
sm_shop_chat_use_prefix_file "0"        // 1 = file-based, 0 = free-form
```

## Key Components & APIs

### Shop Integration
- **Registration**: `Shop_RegisterCategory()` and `Shop_StartItem()`
- **Callbacks**: Item registration, usage toggle callbacks
- **Item Types**: All items use `Item_Togglable` type with duration support

### Chat Processing
- **Hook**: `OnClientSayCommand` for custom chat formatting
- **Compatibility**: Checks for CCC plugin and defers if active
- **Formatting**: Manual SayText2 message construction for custom colors

### Client Data Management
- **Storage**: ClientPrefs cookies for persistence
- **Arrays**: Global arrays for runtime color/prefix storage
- **Validation**: Proper client index and connection state checking

## Troubleshooting Common Issues

### Plugin Not Loading
1. **Check Dependencies**: Ensure Shop-Core is loaded first
2. **SourceMod Version**: Requires SM 1.11+ for `#pragma newdecls required`
3. **Include Files**: Verify shop.inc, multicolors.inc are available

### Colors Not Working  
1. **Check CCC Conflict**: Plugin defers to CustomChatColors if enabled
2. **Verify Purchase**: Player must own and toggle items in shop
3. **Config Files**: Ensure `configs/shop/chat_colors.cfg` exists and is readable
4. **Color Format**: Use hex codes without # (e.g., "FF0000" not "#FF0000")

### Prefix Issues
1. **File Mode**: Check `sm_shop_chat_use_prefix_file` setting
2. **Config Missing**: Ensure `configs/shop/chat_prefix.cfg` exists if file mode enabled
3. **Permissions**: Verify file read permissions on config directory

### Chat Not Appearing
1. **Client State**: Player must be in-game, not fake client, not gagged
2. **Team Chat**: Verify team-based message filtering is working correctly  
3. **Message Format**: Check SayText2 message construction

## Common Development Tasks

### Adding New Color Options
1. Edit `addons/sourcemod/configs/shop/chat_colors.cfg`
2. Add entry: `"Color Name" "HEXCODE"`
3. Plugin automatically reloads config on map change

### Modifying Price/Duration
1. Update ConVar values in server configuration
2. Changes apply immediately via ConVar callbacks
3. Active items update automatically

### Adding New Prefix Options
1. Edit `addons/sourcemod/configs/shop/chat_prefix.cfg`
2. Add one prefix per line
3. Requires `sm_shop_chat_use_prefix_file 1`

### Debugging Chat Issues
1. Check CCC integration: Plugin defers to CCC if active
2. Verify client state: Must be in-game, not fake client, not gagged
3. Test color codes: Use hex format without # symbol

## Player Commands

### Available In-Game Commands
- **`!color` / `sm_shopcolor`**: Opens color selection menu for purchased items
- **`!myprefix "text"` / `sm_myprefix "text"`**: Sets custom prefix (when free-form mode enabled)
- **`!tag` / `sm_shoptag`**: Alias for prefix command

### Admin Commands  
- All shop items are managed through the Shop-Core admin interface
- ConVar changes take effect immediately via callbacks

## Testing & Validation

### Local Testing
1. **Build**: Run `sourceknight build` to compile
2. **Deploy**: Copy output to SourceMod test server
3. **Dependencies**: Ensure Shop-Core and dependencies are loaded
4. **Configuration**: Verify config files exist and are readable

### Integration Testing
- **Shop Integration**: Verify items appear in shop menus
- **Purchase Flow**: Test buying, using, and selling items
- **Chat Functionality**: Test all color/prefix combinations
- **Persistence**: Verify settings survive reconnection
- **CCC Compatibility**: Test with CCC enabled/disabled

## Important Considerations

### Memory Management
- **Handles**: Always use `CheckCloseHandle()` before reassigning
- **Menus**: Proper cleanup in `MenuAction_End`
- **Timers**: No persistent timers used (duration handled by Shop-Core)

### Performance Notes
- **Chat Hook**: Processes every chat message - keep logic efficient
- **Color Validation**: Minimal string operations in hot paths
- **Menu Caching**: Menus rebuilt only when configuration changes

### Compatibility Issues
- **CCC Integration**: Plugin detects and defers to CustomChatColors
- **SourceMod Versions**: Requires SM 1.11+ for new syntax features
- **Game Compatibility**: Designed for Source engine games (CS:S, CS:GO, etc.)

### Security Considerations
- **Input Validation**: Prefix text should be sanitized
- **Color Codes**: Limited to predefined values or hex validation
- **Client Verification**: Proper bounds checking on client indices

## Common Pitfalls

1. **Missing Dependencies**: Ensure Shop-Core is loaded before this plugin
2. **Config File Paths**: Verify configs exist in correct shop subdirectory
3. **Handle Leaks**: Always close handles when recreating menus
4. **Client State**: Check `IsClientInGame()` before accessing client data
5. **CCC Conflicts**: Plugin automatically handles CCC presence
6. **Color Format**: Use hex codes without # prefix (e.g., "FF0000" not "#FF0000")

## Extending the Plugin

### Adding New Item Types
1. Define new constants and arrays following existing pattern
2. Add ConVars with proper callbacks
3. Register new item in `Shop_Started()`
4. Implement item callbacks
5. Add menu handling and chat processing logic

### Custom Color Validation
- Extend `EditColor()` function for additional validation
- Consider color accessibility and readability
- Add server-side color restrictions if needed

### Enhanced Prefix System
- Consider rich text formatting for prefixes
- Add prefix categories or tiered systems
- Implement prefix expiration notifications

This plugin follows SourceMod best practices and integrates cleanly with the Shop ecosystem. When making modifications, maintain the existing patterns for consistency and compatibility.