package Mojolicious::Plugin::MysqlViewerCheap;
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

my %args = (template_class => __PACKAGE__);
sub register {
    my ($self, $app, $conf) = @_;
    
    my $dbh = $conf->{dbh};
    my $r = $conf->{route} || $app->routes;
    
    $dbi = DBIx::Custom->new;
    $dbi->dbh($dbh);
    
    # Top page
    $r->get('/mysqlviewer', sub {
        my $self = shift;
        my $stash = $self->stash;
        
        $stash->{databases} = _show_databases();
        $stash->{current_database} = _current_database();
        
        return $self->render(%args);
    });
    
    # Database
    $r->get('/mysqlviewer/database', sub {
        my $self = shift;
        
        my $param = $self->req->params->to_hash;
        my $rule = [
            database => {default => ''} => [
                'safety_name'
            ] 
        ];
        my $vresult = $vc->validate($param, $rule);
        my $database = $vresult->data->{database};
        
        my $tables = _show_tables($database);
        
        return $self->render(%args, database => $database, tables => $tables);
    } => 'mysqlviewer-database');
    
    # Table
    $r->get('/mysqlviewer/table', sub {
        my $self = shift;
        
        # Validation
        my $param = $self->req->params->to_hash;
        my $rule = [
            database => {default => ''} => [
                'safety_name'
            ],
            table => {default => ''} => [
                'safety_name'
            ]
        ];
        my $vresult = $vc->validate($param, $rule);
        my $database = $vresult->data->{database};
        my $table = $vresult->data->{table};
        
        my $table_def = _show_create_table($database, $table);
        return $self->render(%args, database => $database, table => $table, 
          table_def => $table_def, current_database => _current_database());
    } => 'mysqlviewer-table');
    
    # List primary keys
    $r->get('/mysqlviewer/listprimarykeys', sub {
        my $self = shift;
        
        # Validation
        my $param = $self->req->params->to_hash;
        my $rule = [
            database => {default => ''} => [
                'safety_name'
            ],
        ];
        my $vresult = $vc->validate($param, $rule);
        my $database = $vresult->data->{database};
        
        # Get primary keys
        my $tables = _show_tables($database);
        my $primary_keys = {};
        foreach my $table (@$tables) {
            my $show_create_table = _show_create_table($database, $table) || '';
            my $primary_key = '';
            if ($show_create_table =~ /PRIMARY\s+KEY\s+(.+?)\n/i) {
                $primary_key = $1;
            }
            $primary_keys->{$table} = $primary_key;
        }
        
        $self->render(%args, database => $database, primary_keys => $primary_keys);
        
    } => 'mysqlviewer-listprimarykeys');

    # List null allowed columns
    $r->get('/mysqlviewer/listnullallowedcolumns', sub {
        my $self = shift;
        
        # Validation
        my $param = $self->req->params->to_hash;
        my $rule = [
            database => {default => ''} => [
                'safety_name'
            ],
        ];
        my $vresult = $vc->validate($param, $rule);
        my $database = $vresult->data->{database};
        
        # Get null allowed columns
        my $tables = _show_tables($database);
        my $null_allowed_columns = {};
        foreach my $table (@$tables) {
            my $show_create_table = _show_create_table($database, $table) || '';
            my @lines = split(/\n/, $show_create_table);
            my $null_allowed_column = [];
            foreach my $line (@lines) {
                next if /^\s*`/ || $line =~ /NOT\s+NULL/i;
                if ($line =~ /^\s+(`\w+?`)/) {
                    push @$null_allowed_column, $1;
                }
            }
            $null_allowed_columns->{$table} = $null_allowed_column;
        }
        
        $self->render(%args, database => $database,
          null_allowed_columns => $null_allowed_columns);
        
    } => 'mysqlviewer-listnullallowedcolumns');

    # List database engines
    $r->get('/mysqlviewer/listdatabaseengines', sub {
        my $self = shift;
        
        # Validation
        my $param = $self->req->params->to_hash;
        my $rule = [
            database => {default => ''} => [
                'safety_name'
            ],
        ];
        my $vresult = $vc->validate($param, $rule);
        my $database = $vresult->data->{database};
        
        # Get null allowed columns
        my $tables = _show_tables($database);
        my $database_engines = {};
        foreach my $table (@$tables) {
            my $show_create_table = _show_create_table($database, $table) || '';
            my $database_engine = '';
            if ($show_create_table =~ /ENGINE=(.+?)\s+/i) {
                $database_engine = $1;
            }
            $database_engines->{$table} = $database_engine;
        }
        
        $self->render(%args, database => $database,
          database_engines => $database_engines);
        
    } => 'mysqlviewer-listdatabaseengines');

    # List database engines
    $r->get('/mysqlviewer/selecttop1000', sub {
        my $self = shift;
        
        # Validation
        my $param = $self->req->params->to_hash;
        my $rule = [
            database => {default => ''} => [
                'safety_name'
            ],
            table => {default => ''} => [
                'safety_name'
            ]
        ];
        my $vresult = $vc->validate($param, $rule);
        my $database = $vresult->data->{database};
        my $table = $vresult->data->{table};
        
        # Get null allowed columns
        my $result = $dbi->select(table => $table, append => 'limit 0, 1000');
        my $header = $result->header;
        my $rows = $result->fetch_all;
        my $sql = $dbi->last_sql;
        
        $self->render(%args, database => $database, table => $table,
          header => $header, rows => $rows, sql => $sql);
    } => 'mysqlviewer-selecttop1000'); 
}

sub _current_database {
    $dbi->execute('select database()')->fetch->[0];
} 

sub _show_databases {
    
    my $databases = [];
    my $database_rows = $dbi->execute('show databases')->all;
    foreach my $database_row (@$database_rows) {
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
    foreach my $table_row (@$table_rows) {
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


1;

__DATA__

@@ layouts/mysqlviewer.html.ep
<!doctype html><html>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" >
  <head>
    <title><%= $title %></title>
    %= javascript '/js/jquery.js'
    
  </head>
  <body>
    %= content;
  </body>
</html>

@@ mysqlviewer.html.ep
% layout 'mysqlviewer', title => 'MySQL Viewer';
<h2>MySQL Viewer</h2>

<h3>Databases</h3>
<ul>
% foreach my $database (sort @$databases) {
  <li>
    <a href="<%= url_for('/mysqlviewer/database')->query(database => $database) %>"><%= $database %>
    %= $current_database eq $database ? '(current)' : ''
  </li>
% }
</ul>

@@ mysqlviewer-database.html.ep
% layout 'mysqlviewer', title => "Database $database";
<h2>Database <%= $database %>
<h3>Tables</h3>
<ul>
% foreach my $table (sort @$tables) {
  <li><a href="<%= url_for('/mysqlviewer/table')->query(database => $database, table => $table) %>"><%= $table %></a></li>
% }
</ul>

<h3>Utility</h3>
<ul>
  <li><a href="<%= url_for('/mysqlviewer/listprimarykeys')->query(database => $database) %>">List primary keys</a></li>
  <li><a href="<%= url_for('/mysqlviewer/listnullallowedcolumns')->query(database => $database) %>">List null allowed columns</a></li>
  <li><a href="<%= url_for('/mysqlviewer/listdatabaseengines')->query(database => $database) %>">List database engines</a></li>
</ul>

@@ mysqlviewer-table.html.ep
% layout 'mysqlviewer', title => "Table $database.$table";
<h2>Table <%= "$database.$table" %>
<h3>show create table</h3>
<pre><%= $table_def %></pre>

<h3>Utilities</h3>
<ul>
  % if ($database eq $current_database) {
    <li><a href="<%= url_for('/mysqlviewer/selecttop1000')->query(database => $database, table => $table) %>">Select top 1000</a></li>
  % }
</ul>

@@ mysqlviewer-listprimarykeys.html.ep
% layout 'mysqlviewer', title => "$database primary keys";
<h3><%= "$database primary keys" %></h3>
<ul>
  % foreach my $table (sort keys %$primary_keys) {
    <li><a href="<%= url_for('/mysqlviewer/table')->query(database => $database, table => $table) %>"><%= $table %></a> <%= $primary_keys->{$table} %></li>
  % }
</ul>

@@ mysqlviewer-listnullallowedcolumns.html.ep
% layout 'mysqlviewer', title => "$database null allowed columns";
<h3><%= "$database null allowed columns" %></h3>
<ul>
  % foreach my $table (sort keys %$null_allowed_columns) {
    <li><a href="<%= url_for('/mysqlviewer/table')->query(database => $database, table => $table) %>"><%= $table %></a> (<%= join(',', @{$null_allowed_columns->{$table}}) %>)</li>
  % }
</ul>

@@ mysqlviewer-listdatabaseengines.html.ep
% layout 'mysqlviewer', title => "$database database engines";
<h3><%= "$database database engines" %></h3>
<ul>
  % foreach my $table (sort keys %$database_engines) {
    <li><a href="<%= url_for('/mysqlviewer/table')->query(database => $database, table => $table) %>"><%= $table %></a> (<%= $database_engines->{$table} %>)</li>
  % }
</ul>

@@ mysqlviewer-selecttop1000.html.ep
% layout 'mysqlviewer', title => "<%= $table %>: Select top 1000";

<h2>Select top 1000</h2>

<table border="1" cellspacing="0" >
  <tr><td>Table name</td><td><%= $table %></td></tr>
  <tr><td>SQL</td><td><%= $sql %></td></tr>
</table>

<br>

<table border="1" cellspacing="0" >
  <tr>
    % foreach my $h (@$header) {
        <th><%= $h %></th>
    % }
  </tr>
  % foreach my $row (@$rows) {
    <tr>
      % foreach my $data (@$row) {
        <td><%= $data %></td>
      % }
    </tr>
  % }
</table>
