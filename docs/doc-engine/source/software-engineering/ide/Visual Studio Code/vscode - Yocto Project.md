# vscode - Yocto Project

a Yocto Project is a complex project structure with several bitbake layers, recipes, SDKs (toolchains), and different software projects (repos) of the application layer which are integrated and/or referenced

vscode can nicely be used as simple project browser to navigate through folder structure as well as for any software component like C/C++, rust, JavaScript (nodejs), shell scripts, … Let's show some use cases here.

# Extensions

There are several extensions found for yp search:

| Name(link) | Date | Details |
|------------|------|---------|
| [yocto-project.yocto-bitbake](https://marketplace.visualstudio.com/items?itemName=yocto-project.yocto-bitbake) | latest:* 19.09.2024 <br> * 2.7.0since:* 19.03.2024 <br> * 2.3.0 | Default: recommendedDownloads: 29.889 |
| [oelint-adv](https://marketplace.visualstudio.com/items?itemName=kweihmann.oelint-vscode) | latest:* 18.10.1024 <br> * 1.6.0since:* 03.11.2020 <br> * 1.3.0 | - [ ] todo verify its usage … |
| [EugenWiens.bitbake](https://marketplace.visualstudio.com/items?itemName=EugenWiens.bitbake) | latest:* 15.03.2018 <br> * 1.1.2since:* 03.06.2018 <br> * 1.0.0 | Deprecated: Use yocto-project.yocto-bitbake extension |

# Settings

There are multiple settings to customize vscode like user, workspace, editor, profile, … settings:

* <https://code.visualstudio.com/docs/getstarted/settings>

## User Settings

User settings are for all vscode instances. The json settings file is located at:

* \~/.config/Code/User/settings.json

Example:

```json
{
    "workbench.colorTheme": "Default Dark+",
    "[python]": {
        "editor.formatOnType": true
    },
    "files.watcherExclude": {
        "build/": true,
        ".git/": true
    },
    "search.exclude": {
        "build/": true,
        ".git/": true
    },
    "update.mode": "none"
}
```

## Workspace Settings

Workspace settings are for the currently open workspace, typically named

```json
.code-workspace
```

Example:

```json
{
	"folders": [
		{
			"path": "."
		}
	],
	"settings": {
		"search.searchOnType": true
	}
}
```

## Profiles

* <https://code.visualstudio.com/docs/getstarted/settings#_profile-settings>

> You can use [profiles in VS Code](https://code.visualstudio.com/docs/editor/profiles) to create sets of customization and quickly switch between them. For example, they are a great way to customize VS Code for a specific programming language.

Linux:

```javascript
$HOME/.config/Code/User/profiles/<profile ID>/settings.json
```

### Create Yocto Profile

Select Preferences → Profiles → New Profile

* Name: yocto
* Base on python profile (copy)
* select Settings site by site

 ![](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/e8cda004-4e09-4bc0-b4f9-11abfafa13e3/2024-12-03-144113_1398x673_scrot(1).png)

Add recommended settings from extension docu:

```json
{
    "files.watcherExclude": {
        "**/build": true
    },
    "search.exclude": {
        "**/build": true
    },
    "C_Cpp.files.exclude": {
        "**/build": true
    },
    "python.analysis.exclude": [
        "**/build"
    ],
    "git.repositoryScanIgnoredFolders": [
        "**/build"
    ]
}
```


## Single Root Workspace

First open yp project folder example leg-cms:


 ![](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/c070e78d-07ae-4282-820e-f047e1e39f09/2024-12-03-112903_901x348_scrot(1).png)

Save the project as workspace:

* Save workspace as…


:::info
vscode suggests <project-root>.code-workspace as default

The vscode docs tell to use simply .code-workspace

- [ ] todo verify if this works nicely also in case of mixed single and multi root workspace …

:::


 ![](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/3233501c-b5d1-4718-b1c1-5a9f85a461b6/2024-12-03-113010_551x285_scrot(1).png)


\

:::info
As soon as the opened folder (project) is saved as workspace vscode shows (workspace) label at root folder of the project.

:::

## Multi Root Workspace

Following shall detail handling of a yp multi root workspace, which is maybe different to a classical multi root workspace of e.g. C++ project etc..

* <https://code.visualstudio.com/docs/editor/multi-root-workspaces#_add-folder-to-workspace>

The yp multi root workspace integrates the main yp development folder at:

* /opt/yocto/

```none
/opt/yocto/
▶ build/        #< root build folder, where each project has its own build folder
▶ keys/         #< root keys folder, where each project has its own secrets folder 
▶ project/      #< root project folder, where each project has its own yp folder
▶ shared/       #< default yp shared folder for all projects (downloads, sstate-cache)
▼ workspace/ -> /media/ldcwem0/sandiskmw/linux-dps-review/ #< active yp project
  ▶ build/
  ▶ doc/
  ▶ layers/
  ▶ tools/
```

The example shows current yp main development folder at my dev PC, where linux-dps is the current active yp project symlinked by /opt/yocto/workspace.

The `/opt/yocto/workspace` is not the multi root workspace, it is the symlink name of the current active yp project. See details at Mixed build support at:

* [linux-dps - HowTo Build Fw](/doc/linux-dps-howto-build-fw-eALvoRDhuJ)

- [ ] describe multi root workspace

## Single Root Workspace - Active yp

The following details how to work on the current active yp using vscode's single root workspace project function. Example is linux-dps yp.

First open the active yp folder at /opt/yocto/workspace:

* CTRL-K CTRL-O

 ![](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/ab6d5487-96c8-469b-a065-62e5a5c4904d/2024-12-05-093634_1100x838_scrot(1).png)


:::info
Somehow, the open folder command created a settings.json file under new folder .vscode. This was mainly done because the default profile had yocto-project.yocto-bitbake extension installed.

I removed Yocto Bitbake from default profile. Anyway, I want to have all vscode specific configs at sub-folder .vscode. So create sub-folder manually if it is not created automatically. I also removed settings.json as it had yocto-project.yocto-bitbake extension settings.

:::

 ![](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/53e0c412-c822-4725-8153-d4a9be9cc5ef/2024-12-05-093706_950x520_scrot(1).png)

### Create Workspace

Save the open folder as workspace:

* File / Save Workspace as …
* name and save the workspace config file at `.vscode/linux-dps.code-workspace`


:::info
It is a good idea to use the specific project name like **linux-dps** instead of a general name like linux-workspace or yp-workspace as it helps to identify the project currently active.

Hint: The vscode file explorer shows also that the root folder is a symbolic link.

:::

 ![](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/40c94109-b021-4b89-95d1-ebacb51304d9/2024-12-05-094159_1097x841_scrot(1).png)

The vscode project or lets say vscode workspace is renamed (displayed) as of the name of the .code-workspace file:

 ![](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/c6cf56cc-5062-49c7-89f7-76732eb5dde0/2024-12-05-095245_945x519_scrot(1).png)


:::info
Typically, the .code-workspace settings would only contain folders settings.

However, as the yocto-project.yocto-bitbake extension was active on creation it added most likely the settings part.

:::

Adapted the settings:

```none
{
	"folders": [
		{
			"path": ".."
		}
	],
	"settings": {
		"python.autoComplete.extraPaths": [
			"${workspaceFolder}/layers/poky/bitbake/lib",
			"${workspaceFolder}/layers/poky/meta/lib"
		],
		"python.analysis.extraPaths": [
			"${workspaceFolder}/layers/poky/bitbake/lib",
			"${workspaceFolder}/layers/poky/meta/lib"
		],
		"files.associations": {
			"*.conf": "bitbake",
			"*.inc": "bitbake"
		},
		"bitbake.buildConfigurations": [
			{
				"name": "Build",
				"buildCommand": "${pathToBitbake} ${buildTarget}",
				"cleanCommand": "${pathToBitbake} -c clean ${buildTarget}",
				"buildTargets": [
					"core-image-minimal",
					"core-image-sato"
				]
			}
		],
		"bitbake.pathToBitbakeFolder": "${workspaceFolder}/layers/poky/bitbake",
		"bitbake.pathToEnvScript": "${workspaceFolder}/layers/poky/oe-init-build-env",
	}
}
```

### Activate Profile

For new vscode windows, the default profile is always active. As the default profile does not support yp development, switch to my yocto profile, which brings yocto-project.yocto-bitbake extension etc..

Open profiles setting:

* File / Preferences / Profiles
* Select the profile yocto

 ![](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/6704e46c-44df-4f38-ab3b-77ae06990e24/2024-12-05-101527_1711x764_scrot(1).png)


:::info
The behavior of profile usage by vscode is not clear for me. I can see following behavior:

* when new window is opened by existing vscode instance, it takes the instances profile as active profile
* than I open the Workspace by file `linux-dps.code-workspace`, which activates yocto profile automatically

The question arises Where does vscode store the active profile information for a specific workspace?

> On Linux, VS Code stores the active profile information for a specific workspace within the state.vscdb file located in the following directory:
>
> ```javascript
> ~/.config/Code/User/globalStorage/state.vscdb
> ```
>
> This file is a SQLite database that stores various information about the state of VS Code, including the active profile for each workspace.
>
> While you can technically access and modify this file, it's generally not recommended to do so manually. Instead, you should use the VS Code UI to manage your profiles and their associations with workspaces.
>
> \
> Here's how you can view and change the active profile for a workspace:
>
> 
> 1. Open the **Command Palette** (Ctrl+Shift+P).  
> 2. Type **"Profiles: Show Contents"** and press Enter.
> 3. This will open the **Profiles** view, where you can see all your profiles and their associated folders and workspaces.
> 4. To change the active profile for a workspace, simply select the desired profile and then click on the **"Associate Workspace"** button.
>
> This is the recommended way to manage your VS Code profiles and their associations with workspaces.


The state.vscdb is SQLite database file:

 ![SQLite Viewer - .../User/globalStorage/state.vscdb](uploads/dab17d54-dfa7-4792-b340-8fdd42442c9d/b0e6831a-6a90-48f3-8c21-773825e995df/2024-12-05-111836_1117x297_scrot(1).png)

> Unfortunately, there's no easily documented, specific table or key that directly maps "workspace X uses profile Y." VS Code's internal storage mechanisms can evolve between versions, making it tricky to give a definitive answer without digging into the source code at a specific release.
>
> However, based on community investigations and some source code analysis, here's a likely scenario:
>
> * **Storage Table:** The data is likely within a table named something similar to
>
>   ```javascript
>   ItemTable
>   ```
>
>    or
>
>   ```javascript
>   Data
>   ```
>
>    within the
>
>   ```javascript
>   state.vscdb
>   ```
>
>    database.
> * **Key Structure:** The mapping might be stored using keys that combine workspace identifiers and profile names in some encoded format. This could involve hashing or unique IDs for both workspaces and profiles.
> * **Value:** The value associated with this key would likely indicate the active profile for that workspace.
>
> **Why it's tricky:**
>
> * **No Official Documentation:** Microsoft doesn't publicly document the internal schema of
>
>   ```javascript
>   state.vscdb
>   ```
>
>   . This is likely intentional, as they can change the structure without needing to maintain backwards compatibility.
> * **Potential for Change:** The exact storage mechanism might vary between VS Code versions.
> * **Complexity:** VS Code's state management involves various layers of abstraction, making it challenging to trace the precise storage location without in-depth code analysis.
>
> **If you're truly determined to find the exact mapping:**
>
> 
> 1. **SQLite Browser:** Use a tool like DB Browser for SQLite to open
>
>    ```javascript
>    state.vscdb
>    ```
>
>    .
> 2. **Inspect Tables:** Examine the tables (likely
>
>    ```javascript
>    ItemTable
>    ```
>
>     or similar) for entries that seem to correlate with your workspaces and profiles. Look for patterns in the keys and values.
> 3. **Cross-Reference:** You might need to cross-reference information from other tables to decode workspace and profile identifiers.
> 4. **Caution:** Avoid modifying the database directly unless you're absolutely sure of what you're doing, as it could corrupt your VS Code settings.
>
> Keep in mind that this is an advanced exploration, and the structure might change in future VS Code updates.

:::

- [ ] todo idea for feature of my upcoming yp tool
  - [ ] support of git repo storing entire yp project including yp workspace settings like this vscode at sub-folder .vscode, etc..

# Yocto Programming with vscode

<https://variwiki.com/index.php?title=Yocto_Programming_with_VSCode>

> This guide demonstrates how to create and debug a C++ application using VS Code on the DART-MX8M-MINI.

- [ ] todo mweitner try it out and compare to other IDEs like CLion etc…