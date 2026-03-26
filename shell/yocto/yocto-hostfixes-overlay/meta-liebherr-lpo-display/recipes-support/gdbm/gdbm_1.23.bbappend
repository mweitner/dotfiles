# gdbm 1.23 tools/var.c uses 'bool' as a field identifier.
# C23 treats bool as a keyword, so force pre-C23 mode for native builds.
CC:append:pn-gdbm-native = " -std=gnu17"
