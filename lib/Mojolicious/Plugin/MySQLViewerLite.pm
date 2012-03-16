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
  
  $self->create_routes(
    $r,
    namespace => 'Mojolicious::Plugin::MySQLViewerLite',
    controller => 'mysqlviewerlite',
    plugin => $self,
    prefix => $self->prefix,
    main_title => 'MySQL Viewer Lite'
  );
}

sub add_renderer_path {
  my ($self, $renderer) = @_;
  my $class = __PACKAGE__;
  $class =~ s/::/\//g;
  $class .= '.pm';
  my $public = abs_path dirname $INC{$class};
  push @{$renderer->paths}, "$public/MySQLViewerLite/templates";
  $self->SUPER::add_renderer_path($renderer);
}

sub create_routes {
  my ($self, $r, %opt) = @_;
  
  $r = $self->SUPER::create_routes($r, %opt);
  $r->get('/showdatabaseengines')->to(%opt, action => 'showdatabaseengines');
  $r->get('/showcharsets')->to(%opt, action => 'showcharsets');

  return $r;
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
