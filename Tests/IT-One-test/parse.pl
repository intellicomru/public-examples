#!/usr/bin/perl

use uni::perl   qw| :dumper |;

use lib '/var/www/lib/';
use utf8;

use mydb;
use util;
use Z;

##  переменные скрипта. 
my  $config_dir='/var/www/';  
my $config_project='itone' ;
my $CONFIG=Config2->new( 'dir'=>$config_dir, 'project' => $config_project );
my $tmp_dir=$CONFIG->{tmp_dir} || '/tmp/';
 
 
my $DB=mydb->new($CONFIG,'IT::ONE');
  my $util = util->new();
  
## разорхивируем файл 
my $gzfile=$ARGV[0] || $tmp_dir."out.gz";
if(!-f $gzfile ){ 
  print "No file $gzfile \n";
  exit;
}

## читаем 
my $file = `/usr/bin/gunzip -c $gzfile`;

foreach my $str  (split(/\n+/,$file)){
   my @row=split(/\s/,$str);
   my %H=();
   $H{created}=$row[0]." ".$row[1];
   $H{int_id} = $row[2];
   $H{str}=join(" ",@row[2..$#row]);
   if($row[3] eq '<='){
      $str =~/\sid\=([^\s]+)/;
       $H{id} = $1;
       /()/;
       ## есть битые строки в логе 2012-02-13 15:07:10 1RwtkU-0005Bt-SA <= <> R=1RwRqg-0006cG-An U=mailnull P=local S=1154
       # такие пропускаем 
       if($H{id}){
         ## сохраняем messages 
         my @A=keys %H;
         $util->clear_row(\%H);
        $DB->insert("message",\%H,\@A);
        #print dumper \%H;
       } 
   }else{
    $H{address} = lc($row[4]);
    my @A=keys %H;
     $util->clear_row(\%H);
     $DB->insert("log",\%H,\@A);
   }  
 }
