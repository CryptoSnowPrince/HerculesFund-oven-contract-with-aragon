#!/bin/sh

sudo su &
echo hello1
yarn install --force;
echo hello2;
npm audit fix --force;
echo hello3;
/home/gitpod/.pyenv/versions/3.8.12/bin/python3 -m pip install --upgrade pip;
echo hello4;
pip3 install solc-select;
echo hello5;
pip3 install slither-analyzer;
echo hello6;
solc-select install;
echo hello7
