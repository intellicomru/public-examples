#!/usr/bin/perl
# https://metacpan.org/pod/Async

use strict;
use IO::Socket::SSL;# qw(debug3);
use Data::Dumper; 
use Async;


print "Start Load\n";

 my $host= "mail.ru";
 my $path = "/";
 my $query={
 		  'text'=>'test',
			};
 my $timeout=10;
  	   
my $proc = Async->new(sub {
       my $res = http_get($host, $path, $query, $timeout);
       return  Dumper $res;
    });


while (1) {
  print "Wait http request : The time is now ", scalar(localtime), "\n";
  my $e;
  if ($proc->ready) {
    if ($e = $proc->error) {
      print "Something went wrong.  The error was: $e\n";
    } else {
      my $rr= $proc->result;
      print "The result of the get $host  is: $rr \n";
    }
    undef $proc;
    last;
  }
  # The result is not ready; we can go off and do something else here.
  sleep 1; # One thing we could do is to take nap.
}

print "End Load\n";

sub http_get{
my ($host, $path, $query, $timeout) = @_;
my $query_string;
if(ref($query) eq 'HASH'){
 my @qs=();
  foreach my $key (keys %{$query}){ push(@qs ,"$key=".$$query{$key}); }
  $query_string = "?".join("&",@qs);
}
sleep 2;
 my %Res=();
 eval {
        local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n обязателен
        alarm $timeout; ## выходим по таймауту 
        my $socket = IO::Socket::SSL->new(
          PeerAddr        => $host,
          PeerPort        => 443,
          SSL_verify_mode => 0x00,
        ) or die "failed to connect: $SSL_ERROR";
      ## заголовок   
     my $req="GET $path HTTP/1.1
User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)
Host: $host\n\n$query_string\n";
	print $socket  $req; 
	## читаем заголовок
	$Res{http_status}=<$socket>;
   while (my $data = <$socket>){
   ## ищем только длину
    if($data =~ /^Content\-Length/i){
        $data =~/(\d+)/;
        $Res{Length}=$1;
     }
     last if $data =~/^\s+/;
   } 
   # тело  :     
   # my $data;
   # if($Res{Length}>0){
   #    read($socket, $data, $Res{Length});
  # }
   # $Res{content}=$data;
    $socket->close(
      SSL_no_shutdown => 1, 
      SSL_ctx_free    => 1,    
   ) or die "not ok: $SSL_ERROR";
    alarm 0;
};
    # если вышли по тайм-ауту $timeout
    if ($@) {
        die unless $@ eq "alarm\n";   # обработка неожиданных ошибок
    }
 return \%Res;   
}
