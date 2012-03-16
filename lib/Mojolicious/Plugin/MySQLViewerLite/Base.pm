use 5.001001;
package Mojolicious::Plugin::MySQLViewerLite::Base;
use Mojo::Base 'Mojolicious::Plugin';
use DBIx::Custom;
use Validator::Custom;
use File::Basename 'dirname';
use Cwd 'abs_path';
use Mojolicious::Plugin::SQLiteViewerLite::Command;
use Carp 'croak';

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

has command => sub { croak "Unimplemented" };

# Viewer
sub register {
  my ($self, $app, $conf) = @_;
  my $dbh = $conf->{dbh};
  my $prefix = $conf->{prefix} // 'sqliteviewerlite';
  my $r = $conf->{route} // $app->routes;

  # Set Attribute
  $self->dbi->dbh($dbh);
  $self->prefix($prefix);
  
  # Add Renderer path
  $self->add_renderer_path($app->renderer);
  
  $r = $self->create_routes($r,
    namespace => 'Mojolicious::Plugin::SQLiteViewerLite',
    controller => 'controller',
    plugin => $self,
    prefix => $self->prefix,
    main_title => 'SQLite Viewer Lite'
  );
}

sub add_template_path {
  my ($self, $renderer, $class) = @_;
  $class =~ s/::/\//g;
  $class .= '.pm';
  my $public = abs_path $INC{$class};
  $public =~ s/\.pm$//;
  warn $public;
  push @{$renderer->paths}, "$public/templates";
}

sub create_routes {
  my ($self, $r, %opt) = @_;
  
  my $prefix = $self->prefix;

  # Routes
  $r = $r->waypoint("/$prefix")->via('get')->to(%opt, action => 'default');
  $r->get('/tables')->to(%opt, action => 'tables');
  $r->get('/table')->to(%opt, action => 'table');
  $r->get('/showcreatetables')->to(%opt, action => 'showcreatetables');
  $r->get('/showprimarykeys')->to(%opt, action => 'showprimarykeys');
  $r->get('/shownullallowedcolumns')->to(%opt, action => 'shownullallowedcolumns');
  $r->get('/showdatabaseengines')->to(%opt, action => 'showdatabaseengines');
  $r->get('/showcharsets')->to(%opt, action => 'showcharsets');
  $r->get('/select')->to(%opt, action => 'select');

  return $r;
}

1;
