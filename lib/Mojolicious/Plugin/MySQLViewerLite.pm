package Mojolicious::Plugin::MySQLViewerLite;
use Mojo::Base 'Mojolicious::Plugin';
use DBIx::Custom;
use Validator::Custom;

# Validator
my $vc = Validator::Custom->new;
$vc->register_constraint(
  safety_name => sub {
    my $name = shift;
    
    return ($name || '') =~ /^\w+$/ ? 1 : 0;
  }
);

# DBI 
my $dbi;

# Viewer
my $viewer = 'mysqlviewerlite';

my %args = (template_class => __PACKAGE__);
sub register {
  my ($self, $app, $conf) = @_;
  
  my $dbh = $conf->{dbh};
  my $path = $conf->{path} // 'mysqlviewerlite';
  my $r = $conf->{route} // $app->routes;
  
  $dbi = DBIx::Custom->new(dbh => $dbh);
  
  # Top page
  $r = $r->waypoint("/$path")->via('get')->to(cb => sub {
    my $self = shift;
    my $database = _show_databases();
    my $current_database = _current_database();
    
    $self->render(
      %args,
      databases => $database,
      current_database => $current_database
    );
  });
  
  # Database
  $r->get('/database' => sub {
    my $self = shift;
    
    my $params = _params($self);
    my $rule = [
      database => {default => ''} => [
        'safety_name'
      ] 
    ];
    my $vresult = $vc->validate($params, $rule);
    my $database = $vresult->data->{database};
    my $tables = _show_tables($database);
    
    return $self->render(
      %args,
      database => $database,
      tables => $tables
    );
  } => "$viewer-database");
  
  # Table
  $r->get('/table', sub {
    my $self = shift;
    
    # Validation
    my $params = _params($self);
    my $rule = [
      database => {default => ''} => [
        'safety_name'
      ],
      table => {default => ''} => [
        'safety_name'
      ]
    ];
    my $vresult = $vc->validate($params, $rule);
    my $database = $vresult->data->{database};
    my $current_database = _current_database();
    my $table = $vresult->data->{table};
    
    my $table_def = _show_create_table($database, $table);
    return $self->render(
      %args,
      database => $database,
      table => $table, 
      table_def => $table_def,
      current_database => $current_database
    );
  } => "$viewer-table");
  
  # Show primary keys
  $r->get('/showprimarykeys', sub {
    my $self = shift;
    
    # Validation
    my $params = _params($self);
    my $rule = [
      database => {default => ''} => [
        'safety_name'
      ],
    ];
    my $vresult = $vc->validate($params, $rule);
    my $database = $vresult->data->{database};
    
    # Get primary keys
    my $tables = _show_tables($database);
    my $primary_keys = {};
    for my $table (@$tables) {
      my $show_create_table = _show_create_table($database, $table) || '';
      my $primary_key = '';
      if ($show_create_table =~ /PRIMARY\s+KEY\s+(.+?)\n/i) {
        $primary_key = $1;
      }
      $primary_keys->{$table} = $primary_key;
    }
    
    $self->render(%args, database => $database, primary_keys => $primary_keys);
    
  } => "$viewer-showprimarykeys");

  # Show null allowed columns
  $r->get('/shownullallowedcolumns', sub {
    my $self = shift;
    
    # Validation
    my $params = _params($self);
    my $rule = [
      database => {default => ''} => [
        'safety_name'
      ],
    ];
    my $vresult = $vc->validate($params, $rule);
    my $database = $vresult->data->{database};
    
    # Get null allowed columns
    my $tables = _show_tables($database);
    my $null_allowed_columns = {};
    for my $table (@$tables) {
      my $show_create_table = _show_create_table($database, $table) || '';
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
    
    $self->render(
      %args,
      database => $database,
      null_allowed_columns => $null_allowed_columns
    );
    
  } =>"$viewer-shownullallowedcolumns");

  # Show database engines
  $r->get('/showdatabaseengines', sub {
    my $self = shift;
    
    # Validation
    my $params = _params($self);
    my $rule = [
      database => {default => ''} => [
        'safety_name'
      ],
    ];
    my $vresult = $vc->validate($params, $rule);
    my $database = $vresult->data->{database};
    
    # Get null allowed columns
    my $tables = _show_tables($database);
    my $database_engines = {};
    for my $table (@$tables) {
        my $show_create_table = _show_create_table($database, $table) || '';
        my $database_engine = '';
        if ($show_create_table =~ /ENGINE=(.+?)\s+/i) {
          $database_engine = $1;
        }
        $database_engines->{$table} = $database_engine;
    }
    
    $self->render(
      %args,
      database => $database,
      database_engines => $database_engines
    );
    
  } => "$viewer-showdatabaseengines");

  # Show database engines
  $r->get('/select', sub {
    my $self = shift;
    
    # Validation
    my $params = _params($self);
    my $rule = [
      database => {default => ''} => [
        'safety_name'
      ],
      table => {default => ''} => [
        'safety_name'
      ]
    ];
    my $vresult = $vc->validate($params, $rule);
    my $database = $vresult->data->{database};
    my $table = $vresult->data->{table};
    
    # Get null allowed columns
    my $result = $dbi->select(table => $table, append => 'limit 0, 1000');
    my $header = $result->header;
    my $rows = $result->fetch_all;
    my $sql = $dbi->last_sql;
    
    $self->render(
      %args,
      database => $database,
      table => $table,
      header => $header,
      rows => $rows,
      sql => $sql
    );
  } =>"$viewer-select"); 
}

sub _current_database { $dbi->execute('select database()')->fetch->[0] }

sub _show_databases {
  
  my $databases = [];
  my $database_rows = $dbi->execute('show databases')->all;
  for my $database_row (@$database_rows) {
    push @$databases, $database_row->{(keys %$database_row)[0]};
  }
  return $databases; 
}

sub _show_tables { 
  my $database = shift;
  my $table_rows;
  eval { $table_rows = $dbi->execute("show tables from $database")->all };
  $table_rows ||= [];
  my $tables = [];
  for my $table_row (@$table_rows) {
    push @$tables, $table_row->{(keys %$table_row)[0]};
  }
  return $tables;
}

sub _show_create_table {
  my ($database, $table) = @_;
  my $table_def_row;
  eval { $table_def_row = $dbi->execute("show create table $database.$table")->one };
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

@@ layouts/mysqlviewerlite.html.ep
<!doctype html><html>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" >
<head>
  <title>
    % if (stash 'title') {
      <%= stash('title') %>
    % }
    &ltMySQL Vewer Lite&gt
  </title>
  %= javascript '/js/jquery.js'
  %= stylesheet begin 
    *, body {
      padding 0;
      margin: 0;
    }
    
    body {
      padding: 60px;
    }
    
    h1 {
      font-size: 300%;
      margin-bottom: 20px;
    }

    h2 {
      font-size: 230%;
      margin-bottom: 15px;
      margin-left: 10px;
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
      border: 1px solid #66AAFF;
      background-color: #FCFCFF;
      color: #66CC77;
      font-size:90%;
      font-style: normal;
      padding-left:8px;
      padding-right:8px;
      padding-top: 3px;
      padding-bottom:3px;
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
  %= content;
</body>
</html>

@@ mysqlviewerlite-header.html.ep
<h1><a href="<%= '/mysqlviewerlite' %>">&lt;MySQL Viewer Lite&gt;</a></h1>

@@ mysqlviewerlite.html.ep
% layout 'mysqlviewerlite';
%= include 'mysqlviewerlite-header';

<h2>Databases</h2>
<ul>
% for my $database (sort @$databases) {
<li>
  <a href="<%= url_for('/mysqlviewerlite/database')->query(database => $database) %>"><%= $database %>
  %= $current_database eq $database ? '(current)' : ''
</li>
% }
</ul>

@@ mysqlviewerlite-database.html.ep
% layout 'mysqlviewerlite', title => "Tables in $database";
%= include 'mysqlviewerlite-header';

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
          <a href="<%= url_for('/mysqlviewerlite/table')->query(database => $database, table => $tables->[$i + $k]) %>"><%= $tables->[$i + $k] %></a></li>
        </td>
      % }
    </tr>
  % }
</table>

<h2>Utilities</h2>
<ul>
<li><a href="<%= url_for('/mysqlviewerlite/showprimarykeys')->query(database => $database) %>">Show primary keys</a></li>
<li><a href="<%= url_for('/mysqlviewerlite/shownullallowedcolumns')->query(database => $database) %>">Show null allowed columns</a></li>
<li><a href="<%= url_for('/mysqlviewerlite/showdatabaseengines')->query(database => $database) %>">Show database engines</a></li>
</ul>

@@ mysqlviewerlite-table.html.ep
% layout 'mysqlviewerlite', title => "$table in $database";
<h1>Table <i><%= $table %></i> in <%= $database %></h1>
<h2>show create table</h2>
<pre><%= $table_def %></pre>

<h2>Query</h2>
<ul>
% if ($database eq $current_database) {
  <li><a href="<%= url_for('/mysqlviewerlite/select')->query(database => $database, table => $table) %>">select * from <%= $table %> limit 0, 1000</a></li>
% }
</ul>

@@ mysqlviewerlite-showprimarykeys.html.ep
% layout 'mysqlviewerlite', title => "Primary keys in $database";
% my $tables = [sort keys %$primary_keys];
<h2>Primary keys in <i><%= $database %></i> (<%= @$tables %>)</h2>
<table>
  % for (my $i = 0; $i < @$tables; $i += 3) {
    <tr>
      % for my $k (0 .. 2) {
        <td>
          <a href="<%= url_for('/mysqlviewerlite/table')->query(database => $database, table => $tables->[$i + $k]) %>"><%= $tables->[$i + $k] %></a> <%= $primary_keys->{$tables->[$i + $k]} %>
        </td>
      % }
    </tr>
  % }
</table>

@@ mysqlviewerlite-shownullallowedcolumns.html.ep
% layout 'mysqlviewerlite', title => "Null allowed columns in $database";
% my $tables = [sort keys %$null_allowed_columns];
<h2>Null allowed columns in <i><%= $database %></i> (<%= @$tables %>)</h2>
<table>
  % for (my $i = 0; $i < @$tables; $i += 3) {
    <tr>
      % for my $k (0 .. 2) {
        <td>
          <a href="<%= url_for('/mysqlviewerlite/table')->query(database => $database, table => $tables->[$i + $k]) %>">
            <%= $tables->[$i + $k] %>
          </a>
          (<%= join(', ', @{$null_allowed_columns->{$tables->[$i + $k]} || []}) %>)
        </td>
      % }
    </tr>
  % }
</table>

@@ mysqlviewerlite-showdatabaseengines.html.ep
% layout 'mysqlviewerlite', title => "Database engines in $database ";
% my $tables = [sort keys %$database_engines];
<h2>Database engines in <i><%= $database %></i> (<%= @$tables %>)</h2>
<table>
  % for (my $i = 0; $i < @$tables; $i += 3) {
    <tr>
      % for my $k (0 .. 2) {
        <td>
          <a href="<%= url_for('/mysqlviewerlite/table')->query(database => $database, table => $tables->[$i + $k]) %>">
            <%= $tables->[$i + $k] %>
          </a>
          (<%= $database_engines->{$tables->[$i + $k]} %>)
        </td>
      % }
    </tr>
  % }
</table>

@@ mysqlviewerlite-select.html.ep
% layout 'mysqlviewerlite', title => "Select * from $table limit 0, 1000";

<h1>select * from <i><%= $table %></i> limit 0, 1000</h1>

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

Mojolicious::Plugin::MySQLViewerLite

=head1 SYNOPSYS

  # Mojolicious::Lite
  plugin 'MySQLViewerLite', dbh => $dbh;

  # Mojolicious
  $app->plugin('MySQLViewerLite', dbh => $dbh);

  # Access
  http://localhost:3000/mysqlviewerlite

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

Display C<primary keys>, C<null allowed columnes>, and C<database engines> in all tables.

=back

=head1 INSTALLATION

L<Mojolicious::Plugin::MySQLViewerLite> need the following module.

  DBIx::Custom;
  Validator::Custom;

And you copy Mojolicious::Plugin::MySQLViewerLite source code
to the following place.

  lib/Mojolicious/Plugin/MySQLViewerLite.pm
