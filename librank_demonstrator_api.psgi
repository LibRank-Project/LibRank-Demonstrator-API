use Plack::Builder;
use LibRank::Demonstrator::API;
use open qw(:locale);

my $api  = LibRank::Demonstrator::API->new();


builder {
  mount '/' => $api;
};
