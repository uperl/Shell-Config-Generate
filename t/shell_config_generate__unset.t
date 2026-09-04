use lib 't/lib';
use Test2::V0 -no_srand => 1;
use Shell::Config::Generate;
use TestLib;

tempdir();

my $config = eval { Shell::Config::Generate->new };

isa_ok $config, 'Shell::Config::Generate';

$config->set( FOO_KEEP => 'bar' );
$config->set( FOO_UNSET => 'baz' );

my $ret = eval { $config->unset( 'FOO_UNSET' ) };
diag $@ if $@;
isa_ok $ret, 'Shell::Config::Generate';

foreach my $shell (qw( tcsh csh bsd-csh bash sh zsh cmd.exe command.com ksh 44bsd-csh jsh powershell.exe pwsh fish ))
{
  subtest $shell => sub {
    my $shell_path = find_shell($shell);
    skip_all "$shell not found" unless defined $shell_path;

    my $env = get_env($config, $shell, $shell_path);
    return unless defined $env;

    is
      $env,
      hash {
        field FOO_KEEP => 'bar';
        etc;
      },
      $shell,
    ;

    ok !exists $env->{FOO_UNSET}, 'FOO_UNSET is not set';

  }
}

done_testing;
