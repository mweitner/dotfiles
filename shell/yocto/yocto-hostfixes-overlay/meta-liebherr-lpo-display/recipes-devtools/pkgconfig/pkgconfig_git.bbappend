# pkgconfig-native bundles glib sources that still use 'bool' as an identifier.
# Force pre-C23 mode so these sources compile on newer host compilers.
CC:append:pn-pkgconfig-native = " -std=gnu17"
