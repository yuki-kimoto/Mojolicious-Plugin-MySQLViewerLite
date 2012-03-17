use 5.001001;
package Mojolicious::Plugin::MySQLViewerLite;
use Mojo::Base 'Mojolicious::Plugin::MySQLViewerLite::Base';
use File::Basename 'dirname';
use Cwd 'abs_path';
use Mojolicious::Plugin::MySQLViewerLite::Command;

our $VERSION = '0.08';

has command => sub {
  my $self = shift;
  my $commond = Mojolicious::Plugin::MySQLViewerLite::Command->new(dbi => $self->dbi);
};

sub register {
  my ($self, $app, $conf) = @_;
  my $prefix = $conf->{prefix} // 'mysqlviewerlite';
  
  # Database
  my $connector = $conf->{connector};
  my $dbh = $conf->{dbh};
  if ($connector) { $self->dbi->connector($connector) }
  else { $self->dbi->dbh($dbh) }
  
  # Add template path
  $self->add_template_path($app->renderer, __PACKAGE__);
  
  # Routes
  my $r = $conf->{route} // $app->routes;
  $self->prefix($prefix);
  $r = $r->waypoint("/$prefix")->via('get')->to(
    'mysqlviewerlite#default',
    namespace => 'Mojolicious::Plugin::MySQLViewerLite',
    plugin => $self,
    prefix => $self->prefix,
    main_title => 'MySQL Viewer Lite',
  );
  $r->get('/tables')->to(
    '#tables',
    utilities => [
      {path => 'showcreatetables', title => 'Show create tables'},
      {path => 'showprimarykeys', title => 'Show primary keys'},
      {path => 'shownullallowedcolumns', title => 'Show null allowed columns'},
      {path => 'showdatabaseengines', title => 'Show database engines'},
      {path => 'showcharsets', title => 'Show charsets'}
    ]
  );
  $r->get('/table')->to('#table');
  $r->get('/showcreatetables')->to('#showcreatetables');
  $r->get('/showprimarykeys')->to('#showprimarykeys');
  $r->get('/shownullallowedcolumns')->to('#shownullallowedcolumns');
  $r->get('/showdatabaseengines')->to('#showdatabaseengines');
  $r->get('/showcharsets')->to('#showcharsets');
  $r->get('/select')->to('#select');

  # Routes (MySQL specific)
  $r->get('/showdatabaseengines')->to('#showdatabaseengines');
  $r->get('/showcharsets')->to('#showcharsets');
}

1;

=head1 NAME

Mojolicious::Plugin::MySQLViewerLite - Mojolicious plugin to display MySQL database information on browser

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

Select * from TABLE

=item *

Display C<primary keys>, C<null allowed columnes>, C<database engines> and C<charsets> in all tables.

=back

=head1 OPTIONS

=head2 C<connector>

  connector => $connector

Connector object such as L<DBIx::Connector> to connect to database.

  my $connector = DBIx::Connector->connect(...);

Connector has C<dbh> method to get database handle.

=head2 C<dbh>

  dbh => $dbh

Database handle object in L<DBI>.

  my $dbh = DBI->connect(...);

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
