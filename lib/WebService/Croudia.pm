package WebService::Croudia;

=head1 NAME

WebService::Croudia - Croudia client for perl.

=head1 SYNOPSIS

  use WebService::Croudia;
  use YAML;
  my $cr = WebService::Croudia->new(
    username   => 'user loginid or mail address',
    passwrod   => 'user password',
    with_login => 1,
  );

  warn YAML::Dump $cr->friends_timeline;
  warn YAML::Dump $cr->public_timeline;
  $cr->update({ status => 'Hello Croudia!'});

=head1 DESCRIPTION

WebService::Croudia is Croudia client for perl.

=cut

use strict;
use warnings;
use utf8;
use Carp;
use Encode;
use WWW::Mechanize;
use Web::Scraper;
use Text::Trim;

=head1 GLOBAL VARIABLE

=over

=item B<VERSION>

=back

=cut

our $VERSION = '0.03';

=head1 CONSTRUCTOR AND STARTUP

WebService::Croudia オブジェクトの作成

=cut

sub new {
  my $class = shift;
  my %args  = @_;
  $args{root}         = 'https://croudia.com';
  $args{last_req}  = time;
  $args{interval}  = 3; #sec.
  my $self = bless {%args}, $class;
  $self->_create_mech;
  $self->login if $self->{with_login};
  return $self;
}

=head1 METHODS

=head2 login

ログインする

=cut

sub login {
  my $self = shift;
  #my $res = $self->get('/');
  my $post = {
    username     => $self->{username},
    password     => $self->{password},
    'checkbox-1' => 'on'
  };
  my $res        = $self->post('/', $post);
  my $csrf_param = $self->_set_csrf_param($res->decoded_content);
  return $csrf_param ? 1 : 0;
}

=head2 post

mech post with interval.

=cut

sub post {
  my $self = shift;
  $self->_sleep_interval;
  my $url = $self->{root}. shift;
  $self->mech->post($url, @_);
}

=head2 get

mech get with interval.

=cut

sub get {
  my $self = shift;
  $self->_sleep_interval;
  my $url = $self->{root}. shift;
  $self->mech->get($url, @_);
}

=head2 mech

accessor for mech.

=cut

sub mech {
  my $self = shift;
  if(scalar @_){
    $self->{'mech'} = shift;
  }
  return $self->{'mech'};
}

=head2 friends_timeline

get friends timeline.:

my $tl = $cr->friebds_timeline();
for my $line (@$tl){
  sprintf("%s%s%s%s\n",
    (
      $line->{status_id},
      $line->{relative_time},
      $line->{user_id},
      $line->{description},
    )
  );
}

=cut

sub friends_timeline {
  my $self = shift;
  my $res  = $self->get('/voices/timeline');
  return $self->_parse_timeline($res->decoded_content);
}

=head2 public_timeline

get the public timeline.:
this method is to use similarly friends_timeline method.

=cut

sub public_timeline {
  my $self = shift;
  my $res  = $self->get('/search/all_voice');
  return $self->_parse_timeline($res->decoded_content);
}

=head2 follower

get follower.

=cut

sub follower {
  my $self  = shift;
  my $user  = shift || $self->{username}; #TODO mail_addressでログインした人どうすんの
  my $users = [];
  my $offset = 0;
  while(1){
      my $res = $self->get(sprintf('/follows/follower/%s?offset=%s', ($user, $offset)));
      my @users_tmp = @{$self->_parse_follows($res->decoded_content)};
      push @$users, @users_tmp;
      last if scalar @users_tmp < 20;
      $offset+=20;
  }
  return $users;
}

=head2 following

get following

=cut

sub following {
  my $self  = shift;
  my $user  = shift || $self->{username}; #TODO mail_addressでログインした人どうすんの
  my $users = [];
  my $offset = 0;
  while(1){
      my $res = $self->get(sprintf('/follows/following/%s?offset=%s', ($user, $offset)));
      my @users_tmp = @{$self->_parse_follows($res->decoded_content)};
      push @$users, @users_tmp;
      last if scalar @users_tmp < 20;
      $offset+=20;
  }
  return $users;

}

=head2 update

post to the Croudia.:

=cut

sub update {
  my $self = shift;
  my $args = shift;
  my $status = $args->{status} || '';
  return unless $status;
  $status = Encode::is_utf8($status) ?
    Encode::decode_utf8($status):
    $status;
  my $res = $self->mech->get('/voices/written');

  $self->mech->submit_form(
    form_number => 1,
    fields      => {
      'voice[tweet]' => $status,
    }
  );

}

=head2 follow

follow user.:
XXX:現時点の仕様では follow/remove がトグルになっている
=cut

sub follow {
  my $self = shift;
  my $user = shift;

  my $post = {
    utf8               => q{},
    authenticity_token => $self->{csrf_param},
    follow_action      => 'enable',
    target_user_name   => $user,
  };
  my $res = $self->post('/follows/target_follow', $post);
}

=head2 remove

remove user.:
XXX:現時点の仕様では follow/remove がトグルになっている
=cut

sub remove {
  my $self = shift;
  my $user = shift;

  my $post = {
    utf8               => q{},
    authenticity_token => $self->{csrf_param},
    follow_action      => 'diable', #XXX:運営側がtypoしている臭い
    target_user_name   => $user,
  };

  my $res = $self->post('/follows/target_follow', $post);

}

=head1 PRIVATE METHODS

=over

=item B<_create_mech>

mech 周りの作成

=cut

sub _create_mech {
  my $self = shift;
  $self->{agent}      ||= __PACKAGE__." ".$VERSION;
  my $mech         = WWW::Mechanize->new(
    agent => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:8.0) Gecko/20100101 Firefox/8.0',
  );
  my $cookie = HTTP::Cookies->new(autosave => 1);
  $mech->cookie_jar($cookie );
  $self->mech($mech);
}

=item B<_sleep_interval>

アタックにならないように前回のリクエストよりinterval秒待つ。

=cut

sub _sleep_interval {
  my $self = shift;
  my $wait = $self->{interval} - (time - $self->{last_req});
  sleep $wait if $wait > 0;
  $self->{last_req} = time;
}

=item B<_sleep_interval>

Cross Site Request Forgery 用のパラメータセット

=cut

sub _set_csrf_param {
  my $self = shift;
  my $html = shift;
  my $scraper = scraper {
    process '//meta[@name="csrf-token"]', token => '@content';
    result 'token';
  };
  my $token = $scraper->scrape($html);
  $self->{csrf_param} = $token;
  return $token;
}

=item B<_parse_timeline>

HTML を scrape して、タイムライン情報を取得

=cut

sub _parse_timeline {
  my $self = shift;
  my $html = shift;
  my $scraper = scraper {
     process '//ul[@data-role="listview"]/li',
       'data[]' => scraper {
         process '//a',         url           => '@href';
         process '//p/span[1]', nick          => 'TEXT';
         process '//p/span[2]', user_id       => 'TEXT';
         process '//p[2]',      description   => 'TEXT';
         process '//p[3]',      relative_time => 'TEXT';
     };
     result 'data';
  };
  my $data = $scraper->scrape($html) || []; 
  return if ref $data ne 'ARRAY';
  my $result = [];
  for my $line (@$data){
    next if ref $line ne 'HASH';
    next if not defined $line->{nick};
    $line->{status_id}     = [split m{/} ,$line->{url}]->[-1];
    $line->{relative_time} = trim($line->{relative_time});
    $line->{user_id}       = trim($line->{user_id});
    push @$result, $line;
  }
  return $result;
}

=item B<_parse_follows>

フォロワー周りの HTML を scarpe してリストにする

=cut

sub _parse_follows {
  my $self = shift;
  my $html = shift;
  my $scraper = scraper {
    process '//li',
      'data[]' => scraper {
        process '//a',          user_id       => '@href';
        process '//p/span[1]',  nick          => 'TEXT';
        process '//p[2]',       description   => 'TEXT';
      };
      result 'data';
  };
  my $data = $scraper->scrape($html) || [];
  return if ref $data ne 'ARRAY';
  my $result = [];
  for my $line (@$data){
    next if ref $line ne 'HASH';
    next if not defined $line->{nick};
    $line->{user_id} = [split m{/} ,$line->{user_id}]->[-1];
    $line->{description} = trim($line->{description});
    push @$result, $line;
  }
  return $result;
}

=back

=cut

1;

__END__

=head1 AUTHOR

Likkradyus E<lt>perl at li do que do jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
