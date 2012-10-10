use strict;
use warnings;
use constant tests_per_shell => 8;
use constant number_of_shells => 5;
use Test::More tests => (tests_per_shell * number_of_shells) + 1;
use Shell::Config::Generate;
use FindBin ();
use Test::Differences;

require "$FindBin::Bin/common.pl";

tempdir();

foreach my $shell (qw( tcsh csh bash sh zsh ))
{
  my $shell_path = find_shell($shell);
  SKIP: {
    skip "no $shell found", tests_per_shell unless defined $shell_path;

    my $config = eval { Shell::Config::Generate->new };
  
    isa_ok $config, 'Shell::Config::Generate';

    my $ret = eval { $config->set( FOO_SIMPLE_SET => 'bar' ) };
    diag $@ if $@;

    $config->set( FOO_ESCAPE1 => '!@#$%^&*()_+-={}|[]\\;:<>?,./~`' );
    $config->set( FOO_ESCAPE2 => "'" );
    $config->set( FOO_ESCAPE3 => '"' );
    $config->set( FOO_NEWLINE => "\n" );
    $config->set( FOO_TAB     => "\t" );
  
    isa_ok $ret, 'Shell::Config::Generate';

    my $env = get_env($config, $shell, $shell_path);

    is $env->{FOO_SIMPLE_SET}, 'bar',                             'FOO_SIMPLE_SET = bar';
    is $env->{FOO_ESCAPE1},    '!@#$%^&*()_+-={}|[]\\;:<>?,./~`', 'FOO_ESCAPE1    = !@#$%^&*()_+-={}|[]\\;:<>?,./~`';
    is $env->{FOO_ESCAPE2},    "'",                               'FOO_ESCAPE2    = \'';
    is $env->{FOO_ESCAPE3},    '"',                               'FOO_ESCAPE3    = "';
    is $env->{FOO_NEWLINE},    "\n",                              'FOO_NEWLINE    = \n';
    is $env->{FOO_TAB},        "\t",                              'FOO_TAB        = \t';
  }
}

