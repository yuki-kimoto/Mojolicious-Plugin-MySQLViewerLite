use 5.001001;
package Mojolicious::Plugin::MySQLViewerLite;
use Mojo::Base 'Mojolicious::Plugin';
use DBIx::Custom;
use Validator::Custom;

our $VERSION = '0.06';

has [qw/dbi validator prefix/];

# Viewer
sub register {
  my ($self, $app, $conf) = @_;
  my $dbh = $conf->{dbh};
  my $prefix = $conf->{prefix} // 'mysqlviewerlite';
  my %args = (template_class => __PACKAGE__);
  $args{prefix} = $prefix;
  my $r = $conf->{route} // $app->routes;
  
  # DBI
  my $dbi = DBIx::Custom->new(dbh => $dbh);
  
  # Validator
  my $validator = Validator::Custom->new;
  $validator->register_constraint(
    safety_name => sub {
      my $name = shift;
      return ($name || '') =~ /^\w+$/ ? 1 : 0;
    }
  );
  
  # Viewer
  my $viewer = $args{viewer};
  $viewer ||= Mojolicious::Plugin::MySQLViewerLite->new(
    dbi => $dbi,
    validator => $validator,
    prefix => $prefix
  );
  
  # Top page
  $r = $r->waypoint("/$prefix")->via('get')->to(cb => sub { $viewer->action_index(shift) });
  
  # Tables
  $r->get('/tables' => sub { $viewer->action_tables(shift) });
  
  # Table
  $r->get('/table' => sub { $viewer->action_table(shift) });

  # Show create tables
  $r->get('/showcreatetables' => sub { $viewer->action_showcreatetables(shift) });
  
  # Show primary keys
  $r->get('/showprimarykeys', sub { $viewer->action_showprimarykeys(shift) });

  # Show null allowed columns
  $r->get('/shownullallowedcolumns', sub { $viewer->action_shownullallowedcolumns(shift) });

  # Show database engines
  $r->get('/showdatabaseengines', sub { $viewer->action_showdatabaseengines(shift) });

  # Show charsets
  $r->get('/showcharsets', sub { $viewer->action_showcharsets(shift) });
  
  # Select
  $r->get('/select', sub { $viewer->action_select(shift) });
}

sub action_index {
  my ($viewer, $c) = @_;
  
  my $database = $viewer->show_databases;
  my $current_database = $viewer->current_database;
  
  $c->render(
    'index',
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
    databases => $database,
    current_database => $current_database
  );
}

sub action_tables {
  my ($viewer, $c) = @_;
  
  my $params = _params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ] 
  ];
  my $vresult = $viewer->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  my $tables = $viewer->show_tables($database);
  
  return $c->render(
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
    database => $database,
    tables => $tables
  );
}

sub action_table {
  my ($viewer, $c) = @_;
  
  # Validation
  my $params = _params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
    table => {default => ''} => [
      'safety_name'
    ]
  ];
  my $vresult = $viewer->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  my $table = $vresult->data->{table};
  
  my $table_def = $viewer->show_create_table($database, $table);
  return $c->render(
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
    database => $database,
    table => $table, 
    table_def => $table_def,
  );
}

sub action_showcreatetables {
  my ($viewer, $c) = @_;
  
  # Validation
  my $params = _params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ]
  ];
  my $vresult = $viewer->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  my $tables = $viewer->show_tables($database);
  
  # Get create tables
  my $create_tables = {};
  for my $table (@$tables) {
    $create_tables->{$table} = $viewer->show_create_table($database, $table);
  }
  
  return $c->render(
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
    database => $database,
    create_tables => $create_tables
  );
}

sub action_showprimarykeys {
  my ($viewer, $c) = @_;
  
  # Validation
  my $params = _params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $viewer->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get primary keys
  my $tables = $viewer->show_tables($database);
  my $primary_keys = {};
  for my $table (@$tables) {
    my $show_create_table = $viewer->show_create_table($database, $table) || '';
    my $primary_key = '';
    if ($show_create_table =~ /PRIMARY\s+KEY\s+(.+?)\n/i) {
      $primary_key = $1;
      $primary_key =~ s/,$//;
    }
    $primary_keys->{$table} = $primary_key;
  }
  
  $c->render(
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
    database => $database,
    primary_keys => $primary_keys
  );
}

sub action_shownullallowedcolumns {
  my ($viewer, $c) = @_;
  
  # Validation
  my $params = _params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $viewer->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get null allowed columns
  my $tables = $viewer->show_tables($database);
  my $null_allowed_columns = {};
  for my $table (@$tables) {
    my $show_create_table = $viewer->show_create_table($database, $table) || '';
    my @lines = split(/\n/, $show_create_table);
    my $null_allowed_column = [];
    for my $line (@lines) {
      next if /^\s*`/ || $line =~ /NOT\s+NULL/i;
      if ($line =~ /^\s+(`\w+?`)/) {
        push @$null_allowed_column, $1;
      }
    }
    $null_allowed_columns->{$table} = $null_allowed_column;
  }
  
  $c->render(
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
    database => $database,
    null_allowed_columns => $null_allowed_columns
  );
}

sub action_showdatabaseengines {
  my ($viewer, $c) = @_;
  
  # Validation
  my $params = _params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $viewer->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get null allowed columns
  my $tables = $viewer->show_tables($database);
  my $database_engines = {};
  for my $table (@$tables) {
    my $show_create_table = $viewer->show_create_table($database, $table) || '';
    my $database_engine = '';
    if ($show_create_table =~ /ENGINE=(.+?)(\s+|$)/i) {
      $database_engine = $1;
    }
    $database_engines->{$table} = $database_engine;
  }
  
  $c->render(
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
    database => $database,
    database_engines => $database_engines
  );
}

sub action_showcharsets {
  my ($viewer, $c) = @_;
  
  # Validation
  my $params = _params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $viewer->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get charsets
  my $tables = $viewer->show_tables($database);
  my $charsets = {};
  for my $table (@$tables) {
    my $show_create_table = $viewer->show_create_table($database, $table) || '';
    my $charset = '';
    if ($show_create_table =~ /CHARSET=(.+?)(\s+|$)/i) {
      $charset = $1;
    }
    $charsets->{$table} = $charset;
  }
  
  $c->render(
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
    database => $database,
    charsets => $charsets
  );
}

sub action_select {
  my ($viewer, $c) = @_;
  
  # Validation
  my $params = _params($c);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
    table => {default => ''} => [
      'safety_name'
    ]
  ];
  my $vresult = $viewer->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  my $table = $vresult->data->{table};
  
  # Get null allowed columns
  my $result = $viewer->dbi->select(table => "$database.$table", append => 'limit 0, 1000');
  my $header = $result->header;
  my $rows = $result->fetch_all;
  my $sql = $viewer->dbi->last_sql;
  
  $c->render(
    template_class => 'Mojolicious::Plugin::MySQLViewerLite',
    prefix => $viewer->prefix,
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

sub _params {
  my $c = shift;
  my $params = {map {$_ => $c->param($_)} $c->param};
  return $params;
}

1;

__DATA__

@@ layouts/common.html.ep
<!doctype html><html>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" >
<head>
  <title>
    % if (stash 'title') {
      <%= stash('title') %>
    % }
    MySQL Vewer Lite
  </title>
  %= javascript '/js/jquery.js'
  %= stylesheet begin 
    *, body {
      padding 0;
      margin: 0;
    }
    
    #container {
      padding-top: 15px;
      padding-bottom: 15px;
      padding-left: 15px;
      padding-right: 15px;
    }
    
    h1 {
      text-align: center;
      font-size: 250%;
      padding-top: 5px;
      padding-bottom: 5px;
      padding-left: 40px;
      background-color: #F9F9FF
    }

    h2 {
      font-size: 230%;
      margin-bottom: 15px;
      margin-left: 10px;
    }

    h3 {
      font-size: 200%;
      margin-bottom: 15px;
      margin-left: 30px;
    }
    
    ul {
      margin-left: 8px;
      font-size: 190%;
      list-style-type: circle;
    }
    
    li {
      margin-bottom: 6px;
    }
    
    a, a:visited {
      color: #0000EE;
      text-decoration: none;
    }
    
    a:hover {
      color: #EE0000;
    }
    
    i {
      color: #66CC77;
      font-style: normal;
      font-size: 95%;
    }
    
    table {
      border-collapse: collapse;
      margin-left:35px;
      margin-bottom:20px;
    }
    
    table, td, th {
      border: 1px solid #9999CC;
      padding-left:7px;
      padding-right:7px;
      padding-top: 2px;
      padding-bottom: 3px;
    }
    
    pre {
      border: 1px solid #9999CC;
      padding:15px;
      margin-left:35px;
      margin-bottom:20px;
    }

  % end
  
</head>
<body>
  <h1><a href="<%= "/$prefix" %>">MySQL Viewer Lite</a></h1>
  <hr>
  <div id="container">
    %= content;
  </div>
</body>
</html>

@@ index.html.ep
% layout 'common';

<h2>Databases</h2>
<ul>
% for my $database (sort @$databases) {
<li>
  <a href="<%= url_for("/$prefix/tables")->query(database => $database) %>"><%= $database %>
  %= $current_database eq $database ? '(current)' : ''
</li>
% }
</ul>

@@ tables.html.ep
% layout 'common', title => "Tables in $database";

%= stylesheet begin
  ul {
    margin-left: 8px;
    font-size: 150%;
    list-style-type: circle;
  }

  li {
    margin-bottom: 6px;
  }

% end

<h2>Tables in <i><%= $database %></i> (<%= @$tables %>)</h2>
<table>
  % for (my $i = 0; $i < @$tables; $i += 3) {
    <tr>
      % for my $k (0 .. 2) {
        <td>
          <a href="<%= url_for("/$prefix/table")->query(database => $database, table => $tables->[$i + $k]) %>"><%= $tables->[$i + $k] %></a></li>
        </td>
      % }
    </tr>
  % }
</table>

<h2>Utilities</h2>
<ul>
  <li><a href="<%= url_for("/$prefix/showcreatetables")->query(database => $database) %>">Show create tables</a></li>
  <li><a href="<%= url_for("/$prefix/showprimarykeys")->query(database => $database) %>">Show primary keys</a></li>
  <li><a href="<%= url_for("/$prefix/shownullallowedcolumns")->query(database => $database) %>">Show null allowed columns</a></li>
  <li><a href="<%= url_for("/$prefix/showdatabaseengines")->query(database => $database) %>">Show database engines</a></li>
  <li><a href="<%= url_for("/$prefix/showcharsets")->query(database => $database) %>">Show charsets</a></li>
</ul>

@@ table.html.ep
% layout 'common', title => "$table in $database";
<h2>Table <i><%= $table %></i> in <%= $database %></h2>
<h3>show create table</h3>
<pre><%= $table_def %></pre>

<h3>Query</h3>
<ul>
  <li><a href="<%= url_for("/$prefix/select")->query(database => $database, table => $table) %>">select * from <%= $table %> limit 0, 1000</a></li>
</ul>

@@ showcreatetables.html.ep
% layout 'common', title => "Create tables in $database ";
% my $tables = [sort keys %$create_tables];
<h2>Create tables in <i><%= $database %></i></h2>
% for my $table (@$tables) {
  <pre>
    <%= $create_tables->{$table} =%>
  </pre>
% }

@@ showprimarykeys.html.ep
% layout 'common', title => "Primary keys in $database";
% my $tables = [sort keys %$primary_keys];
<h2>Primary keys in <i><%= $database %></i> (<%= @$tables %>)</h2>
<table>
  % for (my $i = 0; $i < @$tables; $i += 3) {
    <tr>
      % for my $k (0 .. 2) {
        <td>
          % my $table = $tables->[$i + $k];
          % if (defined $table) {
            <a href="<%= url_for("/$prefix/table")->query(database => $database, table => $table) %>">
              <%= $table %>
            </a>
            <%= $primary_keys->{$table} || '()' %>
          % }
        </td>
      % }
    </tr>
  % }
</table>

@@ shownullallowedcolumns.html.ep
% layout 'common', title => "Null allowed columns in $database";
% my $tables = [sort keys %$null_allowed_columns];
<h2>Null allowed columns in <i><%= $database %></i> (<%= @$tables %>)</h2>
<table>
  % for (my $i = 0; $i < @$tables; $i += 3) {
    <tr>
      % for my $k (0 .. 2) {
        <td>
          % my $table = $tables->[$i + $k];
          % if (defined $table) {
            <a href="<%= url_for("/$prefix/table")->query(database => $database, table => $table) %>">
              <%= $table %>
            </a>
            (<%= join(', ', @{$null_allowed_columns->{$table} || []}) %>)
          % }
        </td>
      % }
    </tr>
  % }
</table>

@@ showdatabaseengines.html.ep
% layout 'common', title => "Database engines in $database ";
% my $tables = [sort keys %$database_engines];
<h2>Database engines in <i><%= $database %></i> (<%= @$tables %>)</h2>
<table>
  % for (my $i = 0; $i < @$tables; $i += 3) {
    <tr>
      % for my $k (0 .. 2) {
        <td>
          % my $table = $tables->[$i + $k];
          % if (defined $table) {
            <a href="<%= url_for("/$prefix/table")->query(database => $database, table => $table) %>">
              <%= $table %>
            </a>
            (<%= $database_engines->{$table} %>)
          % }
        </td>
      % }
    </tr>
  % }
</table>

@@ showcharsets.html.ep
% layout 'common', title => "Charsets in $database ";
% my $tables = [sort keys %$charsets];
<h2>Charsets in <i><%= $database %></i> (<%= @$tables %>)</h2>
<table>
  % for (my $i = 0; $i < @$tables; $i += 3) {
    <tr>
      % for my $k (0 .. 2) {
        <td>
          % my $table = $tables->[$i + $k];
          % if (defined $table) {
            <a href="<%= url_for("/$prefix/table")->query(database => $database, table => $table) %>">
              <%= $table %>
            </a>
            (<%= $charsets->{$table} %>)
          % }
        </td>
      % }
    </tr>
  % }
</table>

@@ select.html.ep
% layout 'common', title => "Select * from $table limit 0, 1000";

<h2>select * from <i><%= $table %></i> limit 0, 1000</h2>

<table>
<tr>
  % for my $h (@$header) {
      <th><%= $h %></th>
  % }
</tr>
% for my $row (@$rows) {
  <tr>
    % for my $data (@$row) {
      <td><%= $data %></td>
    % }
  </tr>
% }
</table>

__END__

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
