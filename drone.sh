#!/bin/sh

# Get package dependencies
pub get

# Run the tests
dart --checked test/undone_test.dart

# Compile the examples to javascript
pub build example

# Push to gh-pages
git checkout gh-pages
cd build/example/
rsync -rv --exclude=packages . ../..
cd ../../
git add -A
git diff-index --quiet HEAD || git commit -m"auto commit from drone"
git remote set-url origin git@github.com:rmsmith/undone.git
git push origin gh-pages
