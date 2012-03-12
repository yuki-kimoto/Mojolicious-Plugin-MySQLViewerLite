use Mojolicious::Lite;

use DBIx::Custom;
use FindBin;
use lib "lib";

use Mojolicious::Plugin::MySQLViewerLite;
my $dbi = DBIx::Custom->connect(
  dsn => 'dbi:mysql:database=dbix_custom',
  user => 'dbix_custom',
  password => 'dbix_custom'
);

plugin 'MySQLViewerLite', dbh => $dbi->dbh, prefix => 'ppp';

get '/' => {text => 'a'};

app->start;

