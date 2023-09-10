# Ironmon-Tracker

### [General Information](#general-information) | [Supported Games](#supported-games) | [Installation](#installation) | [Latest Changes](#latest-changes) | [Contributing](#contributing)

## General Information

Shiny-Tracker is a collection of lua scripts for the [Bizhawk emulator](https://tasvideos.org/BizHawk/ReleaseHistory) (v2.8 or higher) or [mGBA emulator](https://mgba.io/downloads.html)\* (v0.10.0 or higher) used to track Shiny hunts.
> \* mGBA's lua scripting is currently limited and doesn't provide any drawing functionality, this means the tracker on mGBA is purely text-based in the scripting window as we can't draw images/screens like on Bizhawk. Additionally, it has only been tested on BizHawk.

This project is based on [MKDasher's PokemonBizhawkLua project](https://github.com/mkdasher/PokemonBizhawkLua).

## Supported Games

Currently supported (and tested) Pokémon games / languages:

| Version   | Ruby | Sapphire | Emerald | FireRed | LeafGreen |
| :-------: | :--: | :------: | :-----: | :-----: | :-------: |
| English   | ❌ | ❌ | ❌ | ✔️ | ❌ |
| Spanish   | ❌ | ❌ | ❌ | ❌ | ❌ |
| French    | ❌ | ❌ | ❌ | ❌ | ❌ |
| Italian   | ❌ | ❌ | ❌ | ❌ | ❌ |
| German    | ❌ | ❌ | ❌ | ❌ | ❌ |

## Installation

1. **Download the Tracker**
   - You can get the latest project release from the [Releases](https://github.com/trevorrl/Shiny-Tracker/releases/latest) section of this Github repository.
2. **Get a Supported Emulator**
   - We recommend using the Bizhawk emulator (Windows/Linux only)
      - [Download Bizhawk](https://tasvideos.org/BizHawk/ReleaseHistory) (v2.8 or higher)
      - If you are on Windows, make sure to also download and run the [prereq installer](https://github.com/TASEmulators/BizHawk-Prereqs/releases) first
      - If you are on Linux, we recommend using Bizhawk 2.9 or higher
   - Alternatively, you can use the MGBA emulator (Windows/Mac/Linux)
      - [Download MGBA](https://mgba.io/downloads.html) (v0.10.0 or higher)
3. **Install and Setup**
   - See the full [Installation Guide](https://github.com/trevorrl/Shiny-Tracker/wiki/Installation-Guide) for more detailed instructions for installing or upgrading.
   - If you are on Linux, you'll also want to install the [Franklin Gothic Medium font](https://fontsgeek.com/fonts/Franklin-Gothic-Medium-Regular).
4. **Quickstart Guide**
   - After getting it all setup, check out the [Quickstart Guide](https://github.com/trevorrl/Shiny-Tracker/wiki/Quickstart-Guide) for an overview on how to use the Tracker and learn about all of the information that it displays.

## Latest Changes

### None Yet!

See the project's Wiki for a full [Version Changelog](https://github.com/trevorrl/Shiny-Tracker/wiki/Version-Changelog).

## Contributing

If you'd like to contribute to the tracker, great! Here's some information for you on our processes and setup.

If you're planning to implement a new feature, I'd ask that you either open a feature request issue on GitHub or talk to me in my Discord server about your idea first. This is so we can discuss if it's a good fit for the tracker and how best to implement the feature, before you go through any effort of coding it up.

### What is a good fit for the Shiny Tracker?

The tracker is for more easily tracking and displaying stats around legitimate shiny hunts, _not_ for more easily _getting_ a shiny. As such, any feature ideas/requests should be around improving the hunt tracking experience and not interfere with actual game code/memory at all other than in a read-only fashion.

Additionally, if the feature involves a UI element on the tracker screen, I want to make it as clear and simple to use as I can. There's limited space on the tracker screens so we also want to avoid cramming too many things in or extending the current size of the tracker (as this would mess with many people's stream layouts).

### Development Set-Up

There are a couple of VS Code extensions which we recommend, which should automatically be recommended to you in your VS Code:

- [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig): To help with consistent formatting.
- [vscode-lua](https://marketplace.visualstudio.com/items?itemName=trixnz.vscode-lua): Provides intellisense and linting for Lua.
- [Lua](https://marketplace.visualstudio.com/items?itemName=sumneko.lua): This is Trevor's preferred Lua intellisense extension, provided in addition to the one recommended by the Ironmon Team.

Lua Versions:

- Bizhawk 2.8 uses Lua 5.1, this is the version currently set in our `.vscode/settings.json` file for linting.
- Bizhawk 2.9 and mGBA use Lua 5.4
  - Since we intend to still support Bizhawk 2.8 the code must be compatible with both Lua 5.1 and 5.4

Emu-specific Lua documentation:

- [Bizhawk Lua Functions](https://tasvideos.org/Bizhawk/LuaFunctions)
- [mGBA Scripting API](https://mgba.io/docs/scripting.html)

### Branches and Processes

The primary branches of the Shiny-Tracker repository are as follows:

- **Main**: This is kept in a state of the latest release. We merge into this branch from dev when we are ready to do the final checks and make a new release.
- **Dev**: This is essentially the "staging" build of the next release, where the majority of contributions merge into.
- **Beta-Test**: This branch is for test builds that Tracker users can opt-in to trying out. It regularly gets updated with new features from the dev branch.

**Make your PRs to the Dev branch.**

The workflow we'd recommend for contributing:

1. Create a fork of the repository.
2. Create a branch on your local fork for your new feature/contribution. Make your commits to this branch.
3. When you are ready to send it to us for review, open a Pull Request back to this repository. Request to merge into the **Dev** branch.
4. We'll review the Pull Request and decide whether it needs some changes / more work or if we're happy to merge it in.
