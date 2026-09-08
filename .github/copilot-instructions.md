# Copilot Instructions for ReservedSlot Plugin

## Repository Overview

This repository contains a **SourcePawn plugin for SourceMod** that provides **extended reserved slot functionality** for Source engine game servers. The plugin manages server slots by automatically kicking lower-priority players when reserved slot holders join a full server.

### Plugin Purpose
- Maintains reserved slots for administrators and VIP players
- Implements intelligent player kicking based on priority, activity, and game state
- Integrates with other plugins (AFKManager, EntWatch, Events) for enhanced functionality
- Uses admin immunity levels to determine kick priority

## Technical Environment

### Build System
- **Primary Build Tool**: Native GitHub Actions using the SourcePawn compiler (`spcomp`) via `rumblefrog/setup-sp`
- **Configuration**: `.github/workflows/ci.yml` defines dependency cloning and build targets
- **Dependencies**: Cloned directly from their source repositories in CI
  - SourceMod 1.12.x
  - sm-ext-connect extension
  - AFKManager plugin integration
  - EntWatch plugin integration

### Compilation
```bash
# Build using spcomp directly (CI/CD uses rumblefrog/setup-sp@v1.3.1)
spcomp -i include -o ../plugins/ReservedSlot.smx ReservedSlot.sp
```

### Project Structure
```
addons/sourcemod/scripting/
├── ReservedSlot.sp          # Main plugin file
.github/workflows/ci.yml     # Automated CI/CD pipeline
```

## Core Architecture

### Main Plugin File: `ReservedSlot.sp`

#### Key Global Variables
- `g_Client_Reservation[MAXPLAYERS + 1]` - Stores client immunity levels
- `g_Plugin_AFKManager` - AFKManager integration status
- `g_Plugin_entWatch` - EntWatch integration status  
- `g_Plugin_Events` - Events plugin integration status
- `g_cvEventEnabled` - ConVar for event system status

#### Critical Functions
1. **OnPluginStart()** - Plugin initialization and late loading
2. **OnClientPostAdminCheck()** - Sets client reservation status based on admin flags
3. **OnClientPreConnectEx()** - Main reservation logic, handles slot allocation
4. **KickValidClient()** - Complex logic for selecting which client to kick
5. **ExecuteKickValidClient()** - Performs the actual client kick

#### Plugin Integration Points
- **AFKManager**: Uses `GetClientIdleTime()` native for idle detection
- **entWatch-core** (entWatch 4): Checks `EW_ClientHasItem()` to protect item holders
- **Events Plugin**: Respects event managers during active events

## Development Guidelines

### Code Style (Repository-Specific)
- Follows SourcePawn coding standards with `#pragma semicolon 1` and `#pragma newdecls required`
- Global variables prefixed with `g_`
- Function parameters and local variables use camelCase
- Function names use PascalCase
- Admin immunity levels are core to the plugin's logic

### Key Algorithms

#### Client Kicking Priority (in KickValidClient)
1. **Spectators** - Highest priority for kicking (especially if idle > 30s)
2. **Dead non-donators** - Second priority (if idle > 30s)
3. **Alive non-donators** - Lowest priority (if idle > 30s, no special items)

#### Protection Rules
- **Root admins** - Never kicked
- **Event managers** - Protected during active events
- **Item holders** - Protected if they have EntWatch special items
- **Donators/Reserved slot holders** - Partial protection based on immunity level

### Performance Considerations
- Plugin runs on every client connection attempt
- Avoid expensive operations in `OnClientPreConnectEx()`
- Cache plugin availability checks in `OnAllPluginsLoaded()`
- Use native availability checks before calling external plugin functions

## Build and Testing

### Local Development
1. Install the SourcePawn compiler (`spcomp`) matching SourceMod 1.12.x
2. Compile with `spcomp -i include -o ReservedSlot.smx ReservedSlot.sp`
3. Test on development server with multiple clients
4. Verify reservation logic with different admin levels

### CI/CD Pipeline
- Automatically builds on push/PR using GitHub Actions
- Uses `rumblefrog/setup-sp@v1.3.1` to install the SourcePawn compiler
- Creates release artifacts automatically
- Tags latest builds on main/master branch

### Testing Scenarios
- Full server with mixed admin levels joining
- AFK detection with AFKManager integration
- EntWatch item holder protection
- Event manager protection during active events
- Edge cases: rapid connections, plugin load order

## Integration Dependencies

### Required Dependencies
- **SourceMod 1.12.x**
- **CS:GO/CS2** (uses cstrike include)
- **sm-ext-connect** - For enhanced connection handling

### Optional Dependencies
- **AFKManager** - For accurate idle time detection
- **EntWatch** - For special item holder protection  
- **Events Plugin** - For event manager protection

### Dependency Management
```yaml
# .github/workflows/ci.yml clones dependencies directly from their repos, e.g.:
git clone --depth=1 https://github.com/srcdslab/sm-plugin-AFKManager.git deps/sm-plugin-AFKManager
```

## Common Development Tasks

### Adding New Kicking Criteria
1. Modify `KickValidClient()` function
2. Add new priority array element in `HighestValue[]` and `HighestValueClient[]`
3. Implement logic in the client loop
4. Add to priority checking loop at function end

### Modifying Admin Protection
1. Update `OnClientPostAdminCheck()` for new admin flags
2. Modify protection checks in `KickValidClient()`
3. Consider immunity level comparisons

### Adding Plugin Integrations
1. Add library existence check in `OnAllPluginsLoaded()`
2. Add native availability checks where used
3. Add conditional compilation with `#if defined` blocks
4. Update plugin capabilities logging

## Performance Optimization

### Critical Performance Areas
- `OnClientPreConnectEx()` - Called on every connection attempt
- `KickValidClient()` - Loops through all connected clients
- Admin flag checking - Cached where possible

### Optimization Techniques
- Cache plugin availability rather than checking repeatedly
- Use native availability checks before expensive calls
- Minimize string operations in hot paths
- Leverage SourceMod's built-in admin caching

## Debugging and Troubleshooting

### Common Issues
- Plugin load order affecting integrations
- Native availability timing issues
- Admin database not loaded when client connects
- Immunity level conflicts between plugins

### Debug Information
- Plugin logs capabilities on load in `OnAllPluginsLoaded()`
- Use SourceMod's built-in logging for connection events
- Monitor server console for kick messages

## Version Management

- **Current Version**: 1.2.4
- **Authors**: BotoX, .Rushaway  
- **Versioning**: Follows semantic versioning
- **Releases**: Automated via GitHub Actions with latest tagging

This plugin is a critical server management tool requiring careful testing of any changes due to its impact on player experience and server population management.