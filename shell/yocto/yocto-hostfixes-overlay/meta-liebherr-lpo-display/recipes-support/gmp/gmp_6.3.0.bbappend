# gmp 6.3.0 configure probes rely on pre-C23 function declaration semantics.
# GCC 15 defaults can break these tests; force a stable C dialect for native.
CC:append:pn-gmp-native = " -std=gnu17"
