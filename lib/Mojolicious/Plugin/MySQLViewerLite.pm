use 5.001001;
package Mojolicious::Plugin::MySQLViewerLite;
use Mojo::Base 'Mojolicious::Plugin::MySQLViewerLite::Base';
use File::Basename 'dirname';
use Cwd 'abs_path';
use Mojolicious::Plugin::MySQLViewerLite::Command;

our $VERSION = '0.07';

has command => sub {
  my $self = shift;
  my $commond = Mojolicious::Plugin::MySQLViewerLite::Command->new(dbi => $self->dbi);
};

sub register {
  my ($self, $app, $conf) = @_;
  my $dbh = $conf->{dbh};
  my $prefix = $conf->{prefix} // 'mysqlviewerlite';
  my $r = $conf->{route} // $app->routes;
  
  # Add template path
  $self->add_template_path($app->renderer, __PACKAGE__);
  
  # Set Attribute
  $self->dbi->dbh($dbh);
  $self->prefix($prefix);
  
  # Routes
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

Mojolicious::Plugin::MySQLViewerLite - Mojolicious plugin to display MySQL database information

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
