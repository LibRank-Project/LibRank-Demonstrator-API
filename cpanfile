requires 'Bread::Board';
requires 'Iterator::Simple';
requires 'JSON';
requires 'LWP::UserAgent::Cached';
requires 'Moose';
requires 'Plack::App::File';
requires 'Plack::Builder';
requires 'Raisin', '0.67';
requires 'Types::Standard';
requires 'aliased';
requires 'namespace::autoclean';

on build => sub {
  # required to build LibRank deps
  requires 'Module::Build::Prereqs::FromCPANfile';
}
