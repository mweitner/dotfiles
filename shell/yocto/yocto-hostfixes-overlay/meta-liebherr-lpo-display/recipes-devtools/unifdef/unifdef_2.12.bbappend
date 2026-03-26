# unifdef 2.12 uses 'constexpr' as an identifier in C source.
# C23 reserves constexpr as a keyword, so build native tools in pre-C23 mode.
CC:append:pn-unifdef-native = " -std=gnu17"
