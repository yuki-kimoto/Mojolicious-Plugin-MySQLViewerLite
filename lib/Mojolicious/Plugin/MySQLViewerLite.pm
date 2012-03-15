use 5.001001;
package Mojolicious::Plugin::MySQLViewerLite;
use Mojo::Base 'Mojolicious::Plugin';
use DBIx::Custom;
use Validator::Custom;
use File::Basename 'dirname';
use Cwd 'abs_path';

our $VERSION = '0.06';

has 'prefix';
has validator => sub {
  my $validator = Validator::Custom->new;
  $validator->register_constraint(
    safety_name => sub {
      my $name = shift;
      return ($name || '') =~ /^\w+$/ ? 1 : 0;
    }
  );
  return $validator;
};

has dbi => sub { DBIx::Custom->new };

# Viewer
sub register {
  my ($self, $app, $conf) = @_;
  my $dbh = $conf->{dbh};
  my $prefix = $conf->{prefix} // 'mysqlviewerlite';
  my $r = $conf->{route} // $app->routes;
  
  # Add Renderer path
  $self->add_renderer_path($app->renderer);
  
  # Set Attribute
  $self->dbi->dbh($dbh);
  $self->prefix($prefix);
  
  $r = $self->create_routes($r);
}

sub add_renderer_path {
  my ($self, $renderer) = @_;
  my $class = __PACKAGE__;
  $class =~ s/::/\//g;
  $class .= '.pm';
  my $public = abs_path dirname $INC{$class};
  push @{$renderer->paths}, "$public/MySQLViewerLite/templates";
}

sub create_routes {
  my ($self, $r) = @_;
  
  my $prefix = $self->prefix;

  # Top page
  $r = $r->waypoint("/$prefix")->via('get')->to(cb => sub { $self->action_index(shift) });
  # Tables
  $r->get('/tables' => sub { $self->action_tables(shift) });
  # Table
  $r->get('/table' => sub { $self->action_table(shift) });

  # Show create tables
  $r->get('/showcreatetables' => sub { $self->action_showcreatetables(shift) });
  # Show primary keys
  $r->get('/showprimarykeys', sub { $self->action_showprimarykeys(shift) });
  # Show null allowed columns
  $r->get('/shownullallowedcolumns', sub { $self->action_shownullallowedcolumns(shift) });
  # Show database engines
  $r->get('/showdatabaseengines', sub { $self->action_showdatabaseengines(shift) });
  # Show charsets
  $r->get('/showcharsets', sub { $self->action_showcharsets(shift) });
  
  # Select
  $r->get('/select', sub { $self->action_select(shift) });

  return $r;
}

sub action_index {
  my ($self, $c) = @_;
  
  my $database = $self->show_databases;
  my $current_database = $self->current_database;
  
  $DB::single = 1;
  $c->render(
    controller => 'mysqlviewerlite',
    action => 'index',
    prefix => $self->prefix,
    databases => $database,
    current_database => $current_database
  );
}

sub action_tables {
  my ($self, $c) = @_;
  
  my $params = $self->params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ] 
  ];
  my $vresult = $self->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  my $tables = $self->show_tables($database);
  
  return $c->render(
    controller => 'mysqlviewerlite',
    action => 'tables',
    prefix => $self->prefix,
    database => $database,
    tables => $tables
  );
}

sub action_table {
  my ($self, $c) = @_;
  
  # Validation
  my $params = $self->params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
    table => {default => ''} => [
      'safety_name'
    ]
  ];
  my $vresult = $self->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  my $table = $vresult->data->{table};
  
  my $table_def = $self->show_create_table($database, $table);
  return $c->render(
    controller => 'mysqlviewerlite',
    action => 'table',
    prefix => $self->prefix,
    database => $database,
    table => $table, 
    table_def => $table_def,
  );
}

sub action_showcreatetables {
  my ($self, $c) = @_;
  
  # Validation
  my $params = $self->params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ]
  ];
  my $vresult = $self->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  my $tables = $self->show_tables($database);
  
  # Get create tables
  my $create_tables = {};
  for my $table (@$tables) {
    $create_tables->{$table} = $self->show_create_table($database, $table);
  }
  
  return $c->render(
    controller => 'mysqlviewerlite',
    action => 'showcreatetables',
    prefix => $self->prefix,
    database => $database,
    create_tables => $create_tables
  );
}

sub action_showprimarykeys {
  my ($self, $c) = @_;
  
  # Validation
  my $params = $self->params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $self->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get primary keys
  my $primary_keys = $self->show_primary_keys($database);
  
  $c->render(
    controller => 'mysqlviewerlite',
    action => 'showprimarykeys',
    prefix => $self->prefix,
    database => $database,
    primary_keys => $primary_keys
  );
}

sub action_shownullallowedcolumns {
  my ($self, $c) = @_;
  
  # Validation
  my $params = $self->params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $self->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get null allowed columns
  my $null_allowed_columns = $self->show_null_allowed_columns($database);
  
  $c->render(
    controller => 'mysqlviewerlite',
    action => 'shownullallowedcolumns',
    prefix => $self->prefix,
    database => $database,
    null_allowed_columns => $null_allowed_columns
  );
}

sub action_showdatabaseengines {
  my ($self, $c) = @_;
  
  # Validation
  my $params = $self->params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $self->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get null allowed columns
  my $database_engines = $self->show_database_engines($database);
  
  $c->render(
    controller => 'mysqlviewerlite',
    action => 'showdatabaseengines',
    prefix => $self->prefix,
    database => $database,
    database_engines => $database_engines
  );
}

sub action_showcharsets {
  my ($self, $c) = @_;
  
  # Validation
  my $params = $self->params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $self->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get charsets
  my $charsets = $self->show_charsets($database);
  
  $c->render(
    controller => 'mysqlviewerlite',
    action => 'showcharsets',
    prefix => $self->prefix,
    database => $database,
    charsets => $charsets
  );
}

sub action_select {
  my ($self, $c) = @_;
  
  # Validation
  my $params = $self->params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
    table => {default => ''} => [
      'safety_name'
    ]
  ];
  my $vresult = $self->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  my $table = $vresult->data->{table};
  
  # Get null allowed columns
  my $result = $self->dbi->select(table => "$database.$table", append => 'limit 0, 1000');
  my $header = $result->header;
  my $rows = $result->fetch_all;
  my $sql = $self->dbi->last_sql;
  
  $c->render(
    controller => 'mysqlviewerlite',
    action => 'select',
    prefix => $self->prefix,
    database => $database,
    table => $table,
    header => $header,
    rows => $rows,
    sql => $sql
  );
}

sub current_database {
  my $self = shift;
  return $self->dbi->execute('select database()')->fetch->[0];
}

sub show_primary_keys {
  my ($self, $database) = @_;

  my $tables = $self->show_tables($database);
  my $primary_keys = {};
  for my $table (@$tables) {
    my $primary_key = $self->show_primary_key($database, $table);
    $primary_keys->{$table} = $primary_key;
  }
  return $primary_keys;
}

sub show_primary_key {
  my ($self, $database, $table) = @_;
  my $show_create_table = $self->show_create_table($database, $table) || '';
  my $primary_key = '';
  if ($show_create_table =~ /PRIMARY\s+KEY\s+(.+?)\n/i) {
    $primary_key = $1;
    $primary_key =~ s/,$//;
  }
  return $primary_key;
}

sub show_null_allowed_columns {
  my ($self, $database) = @_;
  my $tables = $self->show_tables($database);
  my $null_allowed_columns = {};
  
  for my $table (@$tables) {
    my $null_allowed_column = $self->show_null_allowed_column($database, $table);
    $null_allowed_columns->{$table} = $null_allowed_column;
  }
  return $null_allowed_columns;
}

sub show_null_allowed_column {
  my ($self, $database, $table) = @_;
  
  my $show_create_table = $self->show_create_table($database, $table) || '';
  my @lines = split(/\n/, $show_create_table);
  my $null_allowed_column = [];
  for my $line (@lines) {
    next if /^\s*`/ || $line =~ /NOT\s+NULL/i;
    if ($line =~ /^\s+(`\w+?`)/) {
      push @$null_allowed_column, $1;
    }
  }
  return $null_allowed_column;
}


sub show_database_engines {
  my ($self, $database) = @_;
  
  my $tables = $self->show_tables($database);
  my $database_engines = {};
  for my $table (@$tables) {
    my $database_engine = $self->show_database_engine($database, $table);
    $database_engines->{$table} = $database_engine;
  }
  
  return $database_engines;
}

sub show_database_engine {
  my ($self, $database, $table) = @_;
  
  my $show_create_table = $self->show_create_table($database, $table) || '';
  my $database_engine = '';
  if ($show_create_table =~ /ENGINE=(.+?)(\s+|$)/i) {
    $database_engine = $1;
  }
  
  return $database_engine;
}

sub show_charsets {
  my ($self, $database) = @_;
  
  my $tables = $self->show_tables($database);
  my $charsets = {};
  for my $table (@$tables) {
    my $charset = $self->show_charset($database, $table);
    $charsets->{$table} = $charset;
  }
  
  return $charsets;
}

sub show_charset {
  my ($self, $database, $table) = @_;
  
  my $show_create_table = $self->show_create_table($database, $table) || '';
  my $charset = '';
  if ($show_create_table =~ /CHARSET=(.+?)(\s+|$)/i) {
    $charset = $1;
  }
  
  return $charset;
}

sub show_databases {
  my $self = shift;
  
  my $databases = [];
  my $database_rows = $self->dbi->execute('show databases')->all;
  for my $database_row (@$database_rows) {
    push @$databases, $database_row->{(keys %$database_row)[0]};
  }
  return $databases;
}

sub show_tables { 
  my ($self, $database) = @_;
  my $table_rows;
  eval { $table_rows = $self->dbi->execute("show tables from $database")->all };
  $table_rows ||= [];
  my $tables = [];
  for my $table_row (@$table_rows) {
    push @$tables, $table_row->{(keys %$table_row)[0]};
  }
  return $tables;
}

sub show_create_table {
  my ($self, $database, $table) = @_;
  my $table_def_row;
  eval { $table_def_row = $self->dbi->execute("show create table $database.$table")->one };
  $table_def_row ||= {};
  my $table_def = $table_def_row->{'Create Table'} || '';
  return $table_def;
}

sub params {
  my ($self, $c) = @_;
  my $params = {map {$_ => $c->param($_)} $c->param};
  return $params;
}

1;

=head1 NAME

Mojolicious::Plugin::MySQLViewerLite - Mojolicious plugin to display mysql database information

=head1 SYNOPSYS

  # Mojolicious::Lite
  plugin 'MySQLViewerLite', dbh => $dbh;

  # Mojolicious
  $app->plugin('MySQLViewerLite', dbh => $dbh);

  # Access
  http://localhost:3000/mysqlviewerlite
  
  # Prefix
  plugin 'MySQLViewerLite', dbh => $dbh, prefix => 'mysqlviewerlite2';

=head1 DESCRIPTION

L<Mojolicious::Plugin::MySQLViewerLite> is L<Mojolicious> plugin
to display MySQL database information on your browser.

L<Mojolicious::Plugin::MySQLViewerLite> have the following features.

=over 4

=item *

Display all table names

=item *

Display C<show create table>

=item *

Select * from TABLE limit 0, 1000

=item *

Display C<primary keys>, C<null allowed columnes>, C<database engines> and C<charsets> in all tables.

=back

=head1 OPTIONS

=head2 C<dbh>

  dbh => $dbh

Database handle object in L<DBI>.

=head2 C<prefix>

  prefix => 'mysqlviewerlite2'

Application base path, default to C<mysqlviewerlite>.

=head2 C<route>

    route => $route

Router, default to C<$app->routes>.

It is useful when C<under> is used.

  my $b = $r->under(sub { ... });
  plugin 'MySQLViewerLite', dbh => $dbh, route => $b;

=cut
