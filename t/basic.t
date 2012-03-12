use Test::More;
use strict;
use warnings;
use DBIx::Custom;
use Test::Mojo;
use Mojo::HelloWorld;

my $database = $ENV{MOJOLICIOUS_PLUGIN_MYSQLVIEWERLITE_TEST_DATABASE}
  // 'mojomysqlviewer';
my $dsn = "dbi:mysql:database=$database";
my $user = $ENV{MOJOLICIOUS_PLUGIN_MYSQLVIEWERLITE_TEST_USER}
  // 'mojomysqlviewer';
my $password = $ENV{MOJOLICIOUS_PLUGIN_MYSQLVIEWERLITE_TEST_PASSWORD}
  // 'mojomysqlviewer';

my $dbi;
eval {
  $dbi = DBIx::Custom->connect(
    dsn => $dsn,
    user => $user,
    password => $password
  );
};

plan skip_all => 'MySQL private test' if $@;

plan 'no_plan';

# Prepare
{
    package Test1;
    use Mojolicious::Lite;
    plugin 'MySQLViewerLite', dbh => $dbi->dbh;
}
my $app = Test1->new;
my $t = Test::Mojo->new($app);

# Top page
$t->get_ok('/mysqlviewerlite')->content_like(qr/$database/);

