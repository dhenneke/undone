#!/bin/sh

# Get package dependencies
pub get

# Run the readme example
dart --checked example/readme.dart

# Run the tests
dart --checked test/undone_test.dart

# Generate API docs and push to gh-pages
# TODO: dartdoc is gone, we need to update to docgen
#dartdoc --package-root packages --include-lib undone lib/undone.dart
#git checkout gh-pages
#cd docs/
#cp -r . ..
#cd ../
#git add -A
#git commit -m"auto commit from drone"
#git remote set-url origin git@github.com:rmsmith/undone.git
#git push origin gh-pages
