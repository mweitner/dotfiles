# fzf - Cheat Sheet

fzf - fuzzy search cheat sheet

* <https://www.freecodecamp.org/news/fzf-a-command-line-fuzzy-finder-missing-demo-a7de312403ff/>

`**+Tab` or `Ctrl+t` or `Alt+c` - open fzf dialog (`$fzf`)

# Searching Files

| command | description |
|---------|-------------|
|         |             |
| `$fzf <query>` | search query as <br> - space separated fuzzy search (fits 90% of cases) <br> -`^` exact begin, `$` exact end (special search of 10% cases) |

# Changing Directory

`cd $fzf` - opens fzf to select directory to change to

# Command History

`Ctrl-r` - open fzf for command history

# Search ssh Hosts

`ssh **+Tab` - lookup recent ip address input and `.ssh/config`

# Send Signal to Process

Replace normal 2 step process of:

* `pgrep <process-name>`
* `kill -9 <id>`

by:

`kill -9 **+Tab` - opens process list with details to select from by fuzzy search