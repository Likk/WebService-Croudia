use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use WebService::Croudia;
use Config::Pit;
use utf8;
use YAML;

my ($cr);
{ #prepare
  my $pit = pit_get('croudia.com', require => {
      username   => 'your loginid or mail address on croudia.com',
      password   => 'your password on croudia.com',
      with_login => 1,
    }
  );

  $cr = WebService::Croudia->new(
    %$pit
  );
}

# scrape member open_social_id
  my $tl = $cr->public_timeline;
  warn YAML::Dump $tl;
  $tl = $cr->friends_timeline;
  warn YAML::Dump $tl;
  my $res = $cr->update({ status => 'Hello Croudia via perl script' });

