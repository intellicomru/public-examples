package Z;
use strict;
use V;
use utf8;
use Compress::Zlib;


# GLOBAL settings
$Z::WorkAsPrint=1;
$Z::Compress=0;


# Local (current page) state
$Z::PageCompress=0;

sub out(@);
sub out(@) { if($Z::WorkAsPrint) {	print @_; } else { $V::ContentBuff.="@_"; } $V::T{Z_OUTPUT_APACHE_COUNT}++; }	
### OLD ###
#

sub tmpl{
  my ($path,$ftmpl)=@_;	
  my $file="$path/$ftmpl";
  $file =~ s/\/+/\//g;
  $file =~ s/\\+/\//g;
  if(-f $file){
    do $file;
    if($@){
      return "Error! $@ $!";
    }
   }else{
   	return "Error! No file $file";
  }
  return ;
}
sub header {
  my $rh=shift; 
  $$rh=~s/\n+/\n/g;	
  $$rh=~s/\n+$//;
  $Z::PageCompress=0;
  if($Z::WorkAsPrint==0 && $Z::Compress>0) {
  	if($ENV{HTTP_ACCEPT_ENCODING}=~/gzip/i) {
  	  $$rh.="\nVary: Accept-Encoding,User-Agent\nContent-Encoding: gzip";
	  $Z::PageCompress=1;
	  }
  	}
  print $$rh."\n\n";
}
#
sub result_print {
  return unless $V::ContentBuff;

  return if $Z::WorkAsPrint==1;

  if($Z::PageCompress==0) { 
	 print $V::ContentBuff;
	} else {
	 print Compress::Zlib::memGzip($V::ContentBuff); 
	}

  undef $V::ContentBuff;
  $V::T{ZIP_CURRENT_PAGE}=$Z::PageCompress if $Z::Compress>0; 
}
#

END { result_print(); }

1;
