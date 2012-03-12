use Test::More;
use strict;
use warnings;
use DBIx::Custom;
use Test::Mojo;
use Mojo::HelloWorld;

{
  package Test::Mojo;
  sub link_ok {
    my ($self, $url) = @_;
    
    my $content = $self->get_ok($url)->tx->res->body;
    while ($content =~ /<a\s+href\s*=\s*"([^"]+?)"/smg) {
      my $link = $1;
      $self->get_ok($link);
    }
  }
}

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

# Prepare database
eval { $dbi->execute('drop table table1') };
eval { $dbi->execute('drop table table2') };
eval { $dbi->execute('drop table table3') };

$dbi->execute(<<'EOS');
create table table1 (
  column1_1 int,
  column1_2 int,
  primary key (column1_1)
) engine=MyIsam;
EOS

$dbi->execute(<<'EOS');
create table table2 (
  column2_1 int not null,
  column2_2 int not null
) engine=InnoDB;
EOS

$dbi->execute(<<'EOS');
create table table3 (
  column3_1 int not null,
  column3_2 int not null
) engine=InnoDB;
EOS

$dbi->insert({column1_1 => 1, column1_2 => 2}, table => 'table1');
$dbi->insert({column1_1 => 3, column1_2 => 4}, table => 'table1');

# Test1.pm
{
    package Test1;
    use Mojolicious::Lite;
    plugin 'MySQLViewerLite', dbh => $dbi->dbh;
}
my $app = Test1->new;
my $t = Test::Mojo->new($app);

# Top page
$t->get_ok('/mysqlviewerlite')->content_like(qr/$database\s+\(current\)/);

# Tables page
$t->get_ok("/mysqlviewerlite/tables?database=$database")
  ->content_like(qr/table1/)
  ->content_like(qr/table2/)
  ->content_like(qr/table3/)
  ->content_like(qr/Show primary keys/)
  ->content_like(qr/Show null allowed columns/)
  ->content_like(qr/Show database engines/);
$t->link_ok("/mysqlviewerlite/tables?database=$database");
