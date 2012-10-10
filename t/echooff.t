use strict;
use warnings;
use Test::More tests => 3;
use Shell::Guess;
use Shell::Config::Generate;

is eval { Shell::Config::Generate->new->echooff->generate(Shell::Guess->bourne_shell) }, "", "echo off = ''";
diag $@ if $@;

is eval { Shell::Config::Generate->new->echooff->generate(Shell::Guess->cmd_shell) }, "\@echo off\n", 'echo off = @echo off';
diag $@ if $@;

is eval { Shell::Config::Generate->new->echooff->echoon->generate(Shell::Guess->cmd_shell) }, "", 'echo off = ""';
diag $@ if $@;

