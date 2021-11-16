package util;

use utf8;
use strict;
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use Time::Local qw( timelocal_posix timegm_posix );
## модуль для небольших общих функций

sub new {  
    my $self = bless {};
   return $self;
 }

# нормализуем 
sub normal{
   my $self=shift;
   my $t=$_[0];
	 $t=lc($t);
	 $t=~s/\s/nbsp/g;
	 $t=~s/\&/amp/g;
   $t=~s/[^a-zа-я0-9\.\_\-]/-/g;
return $t;
}

sub validate_uuid {
    my $self=shift; 
    my $uuid  = shift;
    return $uuid =~ /^[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}$/i ? $uuid : undef;
}

sub to_log {
    my $self=shift; 
    print sprintf( strftime( "%F %T", localtime) . ": %s\n", join(',', map {" $_"} @_));
}

sub get_date{
  my $self=shift;
	my $t=shift || time();
 return strftime "%Y-%m-%d %H:%M:%S", localtime $t;
}

sub get_yyyy_mm_dd{
	my $self=shift;
  my $date=shift || return ;	
	$date=~s /T.*//;
  if($date !~/(\d{4})[\-\.](\d{1,2})[\-\.](\d{1,2})/){
  	if($date =~/(\d{1,2})[\-\.](\d{1,2})[\-\.](\d{4})/){
  	  $date = $3."-".$2."-".$1;
  	}else{ return }  
  }
  return $date;
}
## /\d{4}\-\d{2}-\d{2}$/
## yyyy-mm-dd или dd-mm-yyyy
sub get_date_timegm{
	 my $self=shift;
   my $str=	$self->get_yyyy_mm_dd(shift) || return ;
	 $str =~/(\d{4})\-(\d{1,2})-(\d{1,2})/i;
	 my ($mday, $mon, $year )=($3,$2,int($1));
	 /()()()/;
	 if($year<1900){
	   return ; ## не наш формат 
	 }
	 $mon =~s /^0+//;
	 if(int($mon)<=0){return}
	 $mday =~s /^0+//;
	 $mon--;
	 if($mon>11){return}
   my $date = timegm_posix( 0, 0, 0, $mday, $mon, $year-1900 );
   return $date
}

sub clear_milisec{
  my $self=shift;
	my $t=shift || strftime "%Y-%m-%d %H:%M:%S", localtime time();
	$t =~s/\.\d+$//;
 return $t;
}

sub clear_row{
  my $self=shift;
 	my $H=shift;
 	foreach my $key (keys %{$H}){
 		$$H{$key} =~s/\'/\'\'/g;
   }
 	return 1;
 }
 	
sub makeMD5{
 my $self=shift;
 my $fname = shift;
 return if $fname eq '';
 return unless -f $fname;
 open (my $fh, '<', $fname);
 binmode ($fh);
 my $md5 = Digest::MD5->new->addfile($fh)->hexdigest;
 close ($fh);
 return $md5;
}
#### вспомогательные === 
sub normalize{
	my $self=shift;
	my $t=shift;
	$t=~s/\&amp;/ /g;
	$t=~s/\&nbsp;/ /g;
	$t=~s/\&quot;/ /g;
	$t=~s/[\(\)\s\+\-\.\,\"\:\;\\!\§\@\#\$\%\^\&\*\/\\\'\~\`\>\<\‘]/ /g;
	$t=~s/\s+/ /g;
	$t=~s/^\s+|\s+$//g;
	return lc($t);
	}

1;