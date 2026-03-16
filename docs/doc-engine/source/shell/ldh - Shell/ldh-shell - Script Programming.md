# ldh-shell - Script Programming

Idea is here to doc best practices, cheat sheet, etc around shell scripting. Depending on shell capabilities and compatibility it shall be mostly usable for any shell like zsh, bash, …

However, the bash shell is well known and used widely as the quasi standard shell. At least executing shell scripts. For example, I like to use zsh as my main shell, but the scripts point to bash shell:

```
#!/bin/bash
```

and if shell scripts point to sh shell, it still uses bash as it is symlinked:

```
$ ls -lsa $(which sh)
0 lrwxrwxrwx 1 root root 4 Apr 18 08:52 /usr/bin/sh -> bash
```

whereas zsh can be used to test compatibility;

```
$ ls -lsa $(which zsh)
992 -rwxr-xr-x 1 root root 1013328 Feb 12  2022 /usr/bin/zsh
```

# General

## Error Handling

### Error Flag - e

There is the error flag which can be enabled/disabled. Default is disabled (+e).

Enable error flag:

```
set -e
```

Disable error flag:

```
set +e
```

If error flag is enabled: Shell script terminates, if any command fails with an non-zero return status code. The error message comes from the failing command not script execution.

It is also possible to enable/disable error flag within same script.


:::warning
If script is sourced, the error handling terminates the current shell, where user does not see any message just a terminated shell.

:::

### Guard - source required

If a shell script must be sourced with command `source` or `.` , it makes sense to check this requirement as kind of execution guard.

```
if [ "${BASH_SOURCE}" = "${0}" ]; then
  echo "Error: script must to be sourced"
  exit 254
fi
```

The BASH_SOURCE variable is the executed script as full qualified path e.g.:

```
$ llp_provide_netboot.sh
BASH_SOURCE: /home/ldcwem0/.local/bin/llp_provide_netboot.sh
```

- [ ] todo how does this guard work with symlinks?

# Posix Shell

## Comparision Operators

* <https://tldp.org/LDP/abs/html/comparison-ops.html>

### -n - string is not null


### -z - string is *null*, that is, has zero length


\