#!/bin/sh

VIM="/usr/local/bin/gvim -f"

${VIM} +"syn on" +"set nonumber" +"run! syntax/2html.vim" +"w! ChangeLog.html" +"q!" +"q!" ChangeLog
