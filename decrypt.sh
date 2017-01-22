#!/usr/bin/env bash

gpg2 -d files.tar.xz.gpg | unxz | tar x
rm files.tar.xz.gpg
