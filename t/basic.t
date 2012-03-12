use Test::More;
use strict;
use warnings;
use DBIx::Custom;
use Test::Mojo;
use Mojo::HelloWorld;

my $dsn = $ENV{MOJOLICIOUS_PLUGIN_MYSQLVIEWERLITE_TEST_DSN}
  // 'dbi:mysql:database=mojomysqlviewer';
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
my $app = Mojo::HelloWorld->new;
$app->plugin('MySQLViewerLite', dbh => $dbi->dbh);
my $t = Test::Mojo->new($app);

# Top page
$t->get_ok('/mysqlviewerlite');




