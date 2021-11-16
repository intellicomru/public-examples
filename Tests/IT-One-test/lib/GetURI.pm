package Admin::pm::GetURI;

use lib::abs    qw| ../../../lib . |;
use uni::perl   qw| :dumper |;
use LWP::UserAgent;
use HTTP::Headers;
use Admin::Config2;

sub new{
  my $class = shift;
  my $params=shift;
   my $self = bless {}, $class;
   $self->{params}=$params;
   my $project  = $self->{params}->{project} || 'admin';
   my $dir	= $self->{params}->{dir} ||'/spool/';
   my $cfg= $self->{params}->{cfg_secret} || 'VOIS::RMS';
   my $config = Admin::Config2->new( project => $project , dir=>$dir );
   $self->{'secret_key'}= $config->{$cfg}{'secret_key'};
   $self->{'X-Project-Name'}= $config->{$cfg}{'X-Project-Name'};

  return $self;
}

sub get_url {
  my($self,$url,$ssl)=@_;
  my $ua;
  $url =~ s/^\s+//;
  $url =~ s/\s+$//;
  unless($url){ return }
  if($url =~ /^https/i){ $ssl=1; }
  if($ssl){
    $ua=LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
  }else{
    $ua=LWP::UserAgent->new();
  }  

  my @agent=('Mozilla/5.0 (Windows NT 6.1; DEV Support Robot) Gecko/20130406 Firefox/23.0');

 my $h = HTTP::Headers->new();
    $h->header('X-Secret-Key'       => $self->{'secret_key'} ) if $self->{'secret_key'} ;
    $h->header('X-Project-Name'     => $self->{'X-Project-Name'}) if $self->{'X-Project-Name'};
    $h->header('User-Agent'         => $self->{'ua'}) || $agent[0];
    
 $ua->default_headers($h);
 
  my $request=HTTP::Request->new('GET',$url);
#  print "$url\n";
  my $res=$ua->request($request);
   if ($res->is_success) {
     return  $res->content;
  }
  else {
     print "Error: " . $res->status_line . "\n";
     
  }  
  return undef;	
}
1;