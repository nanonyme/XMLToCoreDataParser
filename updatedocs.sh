#!/bin/sh
if [ ! -d docs ];then
mkdir docs
fi
cd docs
if [ ! -d .git ];then
git init
git remote add origin git://github.com/nanonyme/SimpleLoop.wiki.git
fi
git pull origin master
cd ..
