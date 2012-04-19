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

  #ねがぼをフォローする
  my $follwers = $cr->follow('negatibot');

