# Shell - zsh

Why zsh shell:

* flexible and customizable
* powerfull auto completion engine
* provides vi mode for vim lovers
* important and active community
* bash scripts are mostely compatible

Note However do not use one of it's advertised frameworks on top of zsh, as it makes it too complex.

The following is valid for ArchLinux as prototype as well as:

* Ubuntu (server)
* Fedora (todo)

# Install

```javascript
$ sudo pacman -S zsh
```

ubuntu:

```javascript
$ sudo apt install zsh
```

Important for further configuration especially for pimping zsh prompt, is to have locale setup properly, because I had layout problems with zsh prompt when my locale was on `C` set. So make sure we have e.g. locale `en_US` setup by using locale-gen, and localectl commands.

# True Color Support

rxvt support true color:

```javascript
~ > printf "\x1b[38;2;255;100;0mTRUECOLOR\x1b[0m\n"
TRUECOLOR
~ > echo $COLORTERM
rxvt-xpm
```

# Configure

We us 2 config files of the 5 possible:

* .zshenv - dedicated to environment variables
* .zshrc - configures shell itself and runs commands

```javascript
$ touch ~/.zshrc
$ touch ~/.config/zsh/.zshenv
```

The actual zsh configuration can be found at my dotfiles repo:

* <https://github.com/mweitner/dotfiles>

## Pimp Zsh Prompt

Current prompt after initial install:

```javascript
sloth% echo $USER
michael
sloth% pwd       
/home/michael/dotfiles
sloth% git branch 
* main
sloth% 
```

After pimping:

* I am not sure about the one line gap for each command and I do not really like the right hand side output with git details

```bash
~ > cd dotfiles                                                               
                                                                               
~/dotfiles > echo $USER                                        λ:main  [   ]
michael
                                                                               
~/dotfiles > pwd                                               λ:main  [   ]
/home/michael/dotfiles
                                                                               
~/dotfiles > git branch                                        λ:main  [   ]
* main
                                                                               
~/dotfiles >                                                   λ:main  [   ]
```

to be honest I like my current bash layout:

```javascript
[michael@sloth dotfiles]$ echo $USER
michael
[michael@sloth dotfiles]$ pwd
/home/michael/dotfiles
[michael@sloth dotfiles]$ git branch
* main
[michael@sloth dotfiles]$ 
```

## Directory Stack

zsh is setup for nice dir stack with alias `d` which shows last n elements on stack with index number to jump to. For example jump to stack element #1

```javascript
~/dotfiles/zsh > cd ~                                          λ:main  [   ]
                                                                               
~ > d                                                                         
0	~
1	~/dotfiles/zsh
                                                                               
~ > 1                                                                         
~/dotfiles/zsh
                                                                               
~/dotfiles/zsh >                                               λ:main  [   ]      
```

## Enable Vi Mode

zsh support a vi mode to act similar to vim at command line:

* dotfiles repo contains cursor style `zsh/external/cursor_mode`
* vi `hjkl` navigation is supported for zsh's auto completion menu

```javascript
$ vim ~/.config/zsh/.zshrc
...
#enable vi mode
bindkey -v
export KEYTIMEOUT=1
autoload -Uz cursor_mode && cursor_mode
:wq
```

## Edit command with vi

Its also possible to setup mode in which zsh let command line be edited within system editor in our case vim:

* at command line in command mode press v to open vim editor to edit command line

```javascript
$ vim ~/.config/zsh/.zshrc
...
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line
:wq
```

# zsh plugins

extend zsh with some extensions:

* support more cli commands for auto completion
  * <https://github.com/zsh-users/zsh-completions>
* enable syntax highlighting
  * important to source at end of .zshrc to enable syntax highlighting for all functions above it
  * <https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md>
* support `bd` command jumping to parent directory
* use fuzzy finder `fzf` and install `ripgrep (rg)` for quicker alternative to underlying `find` command.
* custom script support

```bash
~ > sudo pacman -S --noconfirm zsh-completions zsh-syntax-highlighting fzf ripgrep
```

ubuntu:

* zsh-completions and zsh-syntax-highlighting (not supported by official apt repository). therefor install dep package

```javascript
michael@snake:~/Downloads$ wget \
  https://download.opensuse.org/repositories/shells:/zsh-users:/zsh-completions/xUbuntu_21.10/amd64/zsh-completions_0.33.0-1+1.1_amd64.deb
michael@snake:~/Downloads$ sudo dpkg -i zsh-completions_0.33.0-1+1.1_amd64.deb
michael@snake:~/Downloads$ wget \
  https://download.opensuse.org/repositories/shells:/zsh-users:/zsh-syntax-highlighting/xUbuntu_21.10/amd64/zsh-syntax-highlighting_0.6.0-1+5.1_amd64.deb
~/Downloads$ sudo dpkg -i zsh-syntax-highlighting_0.6.0-1+5.1_amd64.deb
$ sudo apt install -y fzf ripgrep
```

add to zshrc:

```bash
~ > vim .config/zsh/.zshrc
...
if [ $(command -v "fzf") ]; then
  source /usr/share/fzf/completion.zsh
  source /usr/share/fzf/key-bindings.zsh
fi
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source "$DOTFILES/zsh/external/bd.zsh"
source "$DOTFILES/zsh/scripts.sh"
:wq
```

add to zshenv:

* let fzf use ripgrep instead of find and ignore .git folders

```javascript
~ > vim .zshenv
...
export FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
:wq
```

jump to directory:

```javascript
~/book-src/mousless-book-companion/part_II > bd 2                                                                         
~/book-src >
```

# Start i3

Let's move `~/.xinitrc` to our dotfiles repo, and let our zsh shell `~/.config/zsh/.zshrc` start i3 automatically after terminal login. i3 is only started if terminal is tty1 and no other i3 process exists:

```javascript
~ > vim dotfiles/zsh/.zshrc
...
if [ "$(tty)" = "/dev/tty1" ]; then
  pgrep i3 || exec startx "$XDG_CONFIG_HOME/X11/.xinitrc"
fi
:wq
```

# Q&A

## Error - zsh compinit: insecure directories

When starting devshell of yp build I get following error:

* <https://www.godo.dev/tutorials/macos-fix-zsh-compinit-insecure-directories/?utm_content=cmp-true>


* <https://stackoverflow.com/questions/13762280/zsh-compinit-insecure-directories>
* <https://github.com/zsh-users/zsh-completions/issues/680>
* <https://github.com/zsh-users/zsh-completions/issues/433>

```none
zsh compinit: insecure directories, run compaudit for list.
Ignore insecure directories and continue [y] or abort compinit [n]? y(eval):unsetopt:1: can't drop privileges; failed to set supplementary group list: operation not permitted
(eval):1: can't change option: privileged
(eval):unsetopt:1: can't drop privileges; failed to set supplementary group list: operation not permitted
(eval):1: can't change option: privileged
```