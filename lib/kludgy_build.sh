#!/bin/sh

# Temporary mini-build script.  Super kludgy, just getting stuff going.

# Compile coffeescript to tmp.
tmp="$(mktemp)"
coffee -p -c froth.coffee > $tmp

# Replace cssom require w/ inlined.
sed 's|'"Froth.cssom = require('./contrib/cssom.min.js')"'|MARKER|' $tmp | sed -e '/MARKER/r contrib/cssom.min.js' -e '/MARKER/d' | sed 's|CSSOM = exports;|Froth.cssom = CSSOM = {};|' > froth.js
