#!/bin/sh

# Get package dependencies
pub get

# Run the readme example
dart --checked example/readme.dart

# Run the tests
dart --checked test/undone_test.dart

# Generate API docs and push to gh-pages
docgen --compile --package-root packages --no-include-sdk --no-include-dependent-packages lib/undone.dart
rm -r packages/
mkdir packages
git checkout gh-pages
cd dartdoc-viewer/client/out/web/
rsync -rv --exclude=packages . ../../../..
rsync -rv --exclude=*.dart ../packages ../../../..
cd ../../../../
git add -A
git diff-index --quiet HEAD || git commit -m"auto commit from drone"
git remote set-url origin git@github.com:rmsmith/undone.git
git push origin gh-pages
