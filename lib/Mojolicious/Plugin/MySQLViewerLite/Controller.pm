package Mojolicious::Plugin::MySQLViewerLite::Controller;
use Mojo::Base 'Mojolicious::Plugin::SQLiteViewerLite::Controller';

sub tables {
  my $self = shift;
  $self->stash->{template} = 'mysqlviewerlite/tables';
  $self->SUPER::tables;
}

sub showdatabaseengines {
  my $self = shift;;
  
  my $plugin = $self->stash->{plugin};
  my $command = $plugin->command;

  # Validation
  my $params = $command->params($self);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $plugin->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get primary keys
  my $database_engines = $command->show_database_engines($database);
  
  $self->stash->{template} = 'mysqlviewerlite/showdatabaseengines'
    unless $self->stash->{template};

  $self->render(
    database => $database,
    database_engines => $database_engines
  );
}

sub showcharsets {
  my $self = shift;;
  
  my $plugin = $self->stash->{plugin};
  my $command = $plugin->command;

  # Validation
  my $params = $command->params($self);
  my $rule = [
    database => {default => ''} => [
      'safety_name'
    ],
  ];
  my $vresult = $plugin->validator->validate($params, $rule);
  my $database = $vresult->data->{database};
  
  # Get primary keys
  my $charsets = $command->show_charsets($database);
  
  $self->stash->{template} = 'mysqlviewerlite/showcharsets'
    unless $self->stash->{template};

  $self->render(
    database => $database,
    charsets => $charsets
  );
}

1;
