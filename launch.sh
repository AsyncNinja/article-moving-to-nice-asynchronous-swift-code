#! /bin/bash

swift build
PERSONS_JSON=$PWD/Resources/persons.json

"./.build/debug/Step 0 - Sync" $PERSONS_JSON
"./.build/debug/Step 1.0 - Callbacks" $PERSONS_JSON
"./.build/debug/Step 1.1 - Callbacks Full Story" $PERSONS_JSON
"./.build/debug/Step 2.0 - Futures" $PERSONS_JSON
"./.build/debug/Step 2.1 - Futures Full Story" $PERSONS_JSON
"./.build/debug/Step 2.2 - Futures and ExecutionContext" $PERSONS_JSON
