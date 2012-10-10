use strict;
use warnings;
use constant tests_per_shell => 3;
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

    my $ret = eval { $config->comment( 'something interesting here' ) };
    diag $@ if $@;
    isa_ok $ret, 'Shell::Config::Generate';

    $config->comment( "and with a \n exit ; new line " );
    $config->comment( "multiple line", "comment" );
    $config->comment( "comment with a trailing backslash: \\" );

    eval { $config->set( FOO_SIMPLE_SET => 'bar' ) };
    diag $@ if $@;

    my $env = get_env($config, $shell, $shell_path);

    is $env->{FOO_SIMPLE_SET}, 'bar', 'FOO_SIMPLE_SET = bar';
  }
}

