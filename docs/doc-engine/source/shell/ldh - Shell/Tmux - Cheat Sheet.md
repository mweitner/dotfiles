# Tmux - Cheat Sheet

| command | description |
|---------|-------------|
| `Ctrl-Space` | $mod (leader key) <br> default: Ctrl-b |

tmux has 2 modes **default** and **copy** mode. Default mode is like vi's insert mode. In  copy mode text from tmux windows can be copied and pasted anywhere. It supports copy of non visual text by select and scroll (see Control section).

 ![tmux architecture](uploads/02026def-d437-4c64-a89a-337add5098db/32b64e7a-0bba-4e4f-aa8f-bdeb30bc5012/2022-04-04-095949_564x300_scrot.png)

**Tmux server**:

* manages multiple **sessions**

**Session**:

* attached or detached from client (terminal e.g. urxvt)

**Window**:

* A window represents a terminal instance of terminal emulator like tty `dev/pts2`.
* Each window is shown as tab in status bar at bottom of tmux session.

**Pane**:

* splits window into **pane**ls, where each pane is a tty like `/dev/pts2`, `/dev/pts3`.

# Orientation

There is very often a misunderstanding of the meaning of vertical and horizontal.

| term | description |     |
|------|-------------|-----|
| vertical | vertical line from top to bottom |     |
| split vertical | cut through vertical line from left to right <br> - split window top/bottom |     |
| horizontal | horizontal line from left to right |     |
| split horizontal | cut through horizontal line from top to bottom <br> - split window left/right |     |

# Control

| command | description |
|---------|-------------|
| `$mod :` | opens command line mode e.g. <br> -`:resize-pane -D 5`to resize pane down by 5 <br> -`:splitw -fh`to split horizontal (left/right) through full window height <br> Alternative the command following`: <command>` <br> - can be executed at terminal with`tmux` |
| `Ctrl-d` or "Prompt> `kill-window`" | kill selected **pane**: <br> - If last pane, kill**window** <br> - if last window, kill**session** <br> - if last session, kill**tmux server** |
| `$mod r` | reload tmux config |
| `$mod Shift+I` | tmux environment reload and plugin initialization (plugin fetch and source) <br> tmux says`TMUX environment reloaded …` <br> `q` - quit plugin load dialog (**not Enter** as the dialog says) |
| `$mode [` | switch from default to copy mode. <br> **Copy tmux terminal text:** <br> -`v` or `V`: start selection <br> -`y`: yank (copy). As we defined `xsel --clipboard`at tmux config it copies into clipboard. <br> - Paste from clipboard anywhere else within your system <br> **Navigate while in copy mode:** <br> - Ctrl+u - scroll up <br> - Ctrl+d - scroll down <br> - \\ - search <br> q - exit copy mode back to default mode |
| `$mod ]` | paste tmux default |

# Session

| command | description |
|---------|-------------|
| `tmux list-sessions` | list all tmux sessions |
| `tmux new-session -s <name>` | create new session with name |
| `tmux attach-session -t <name>` | attach to session name by client |
| `tmux detach-client -s <name>` | detach from session |
| `tmux kill-session -s <name>` | kill session with name |
| `tmux kill-server` | kill tmux server |
| `tmux kill-window` | kill window |
| `tmux move-window -t <target> -s <source>:<id>` | move window with <id> from <source> session to <target> session. <br> e.g. move window 5 of session term-dev to session term-ws1: <br> `tmux move-window -t term-ws1 -s term-dev:5` |


# Window

| Command | Description |
|---------|-------------|
| `$mod [1-n] ` | select window with index n. default: \[0-n\] |
| `$mod f`  | find window. Shows window hierarchy to choose any |
| `$mod w ` | create new window. default: ? |
| `$mod n ` | rename current window |
| `$mod i ` | show info for selected window:pane |
| `$ tmux-new-window <session> <path> <name>` | script opens new tmux window at session with working path and optional name |


# Pane

| command | description |
|---------|-------------|
| *$mod -* | split **vertical**(up/down) <br> split through**f**ull window width: <br> *:splitw -fv* |
| *$mode \|* | split **horizontal**(left/right) <br> split through**f**ull window height: <br> *:splitw -fh* |
| *$mod z* | toggle **zoom** of selected pane to full window size |
| $mod q  | show pane number(s) |

## Pane Layout

There are 5 predefined layouts:

* 1: Even horizontal splits (up/down)
* 2: Even vertical splits (left/right)
* 3: Main pane horizontal (up/down), lesser pane(s) vertical (left/right)
* 4: ?
* 5: Tiled layout

| command | description |
|---------|-------------|
| `$mod Space` | toggle through layouts \[1; 5\] |
| `$mod Alt+[1,2,3,4,5]`  |             |
| `$mod o` | cycle selected pane clockwise <br> Hint:**o**ther |

## Swap Pane

> There is a swap-pane command. The { and } keys are bound to swap-pane -U and swap-pane -D in the default configuration.

swap selected pane with left pane:

```none
$mod {
```

swap selected pane with right pane:

```none
$mod }
```

# Status Bar

\#mod s - show/hide status bar

# Native Search

Since tmux 3.1, regex search is integrated natively into tmux.

| command | description |
|---------|-------------|
| `$mod [` | `/`- input search regex downward <br> `?` - input search regex upward |

# Plugin copycat

Reference:

* <https://github.com/tmux-plugins/tmux-copycat>

| command | description |
|---------|-------------|
| $mod /  | input regex search expression <br> `Enter`- copy highlighted search result (default) <br> in our case:`\ y` (see SpaceVim) |
| $mod \] | paste in tmux terminal if **vi mode** |
|         |             |

# Plugin extractor

quickly select, copy/insert/complete text without a mouse.

Reference:

* <https://github.com/laktak/extrakto>

| command | description |
|---------|-------------|
| `$mod Tab` | open extractor |
|         | `Enter` - copy selection to clipboard |
|         | `Tab` - insert selection into current **pane** |
|         | `Ctrl+h` - open help |

# Tmuxp

| command | description |
|---------|-------------|
| tmuxp freeze | freeze current tmux session by it's name at config path e.g <br> `~/.config/tmuxp/name.yml`. |

```javascript
~ > tmuxp freeze                                                                                                                      
---------------------------------------------------------------
Freeze does its best to snapshot live tmux sessions.

The new config *WILL* require adjusting afterwards. Save config? [y/N]: y
Save to: /home/michael/.config/tmuxp/term-web.yaml [/home/michael/.config/tmuxp/term-web.yaml]: 
Save to /home/michael/.config/tmuxp/term-web.yaml? [y/N]: y
Saved to /home/michael/.config/tmuxp/term-web.yaml.
```