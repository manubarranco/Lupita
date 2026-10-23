#!/bin/sh
# swift-testing with Command Line Tools only (no Xcode): point SwiftPM at the CLT frameworks.
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
if [ -d "$F/Testing.framework" ] && ! xcode-select -p | grep -q Xcode.app; then
  exec swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
fi
exec swift test "$@"
