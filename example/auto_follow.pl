use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use WebService::Croudia;
use List::Compare;
use Config::Pit;
use utf8;

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

  my $followers = [ map { $_->{user_id} } @{$cr->follower}  ];
  my $friends =   [ map { $_->{user_id} } @{$cr->following} ];
  my $lc = List::Compare->new(
    {
      lists => [$followers, $friends ],
      unsorted => 1, #sortする必要はない。
    }
  );

  my $followers_only = $lc->get_Lonly_ref; #フォローされてるけど、フォローしてない。
  my $friends_only   = $lc->get_Ronly_ref; #フォローしてるけど、フォローされてない。

  _follows($followers_only);               #一方的にフォローされてる人を全員フォローし返す
  #_removes($friends_only);                 #フォローしたけど、フォローされ返されてない人をリムーブする


sub _follows {
  my $target = shift;

  for my $user (@$target) {
    $cr->follow($user);
  }
  return 1;
}

sub _removes {
  my $target = shift;

  for my $user (@$target) {
    $cr->remove($user);
  }
  return 1;
}
