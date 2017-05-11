#!/bin/sh

apt install caca-utils
cpan install $(cat cpan-deps.txt)
