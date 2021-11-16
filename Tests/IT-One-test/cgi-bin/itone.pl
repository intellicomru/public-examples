#!/usr/bin/perl

use CGI qw(param Vars);
use strict;
use Encode qw( decode_utf8 encode_utf8 );
use Time::HiRes;
use lib '/var/www/lib/';
use utf8;
use V;
use mydb;
use util;
use Z;

 undef %V::CGI;
 foreach my $key (CGI::param()) { $V::CGI{$key}=decode_utf8(CGI::param("$key")); }


my  $header.="Content-Type: text/html; charset=UTF-8\n\n";
Z::header(\$header);


main();

sub main{
  my $TimeStart=[Time::HiRes::gettimeofday()];    # Точное время старта 
 ##  переменные скрипта. 
   $V::T{config_dir}='/var/www/';  
   $V::T{config_project}='itone' ;
   $V::T{CONFIG}=Config2->new( 'dir'=>$V::T{config_dir}, 'project' => $V::T{config_project} );
   $V::T{tmp_dir}=$V::T{CONFIG}->{tmp_dir} || '/tmp/';
 
 
  $V::T{DB}=mydb->new($V::T{CONFIG},'IT::ONE');
  $V::T{util} = util->new();

 head();
 
  t1();

footer();
 my $dt=sprintf("%.5f",Time::HiRes::tv_interval($TimeStart));
 print "Время работы скрипта: <b>$dt</b> секунд.";
return 1;
}

sub t1{

 my $res=' 
<h2>Форма поиска в логах по Email </h2>

<form action=/cgi-bin/itone.pl>
 <table border=0 cellspacing=4 cellpadding=4>
 <tr><td><input type=text value="'.$V::CGI{search}.'" name=search>&nbsp;&nbsp;&nbsp;<input type=submit value="Искать по Email"><br> <i>пример: <i>xmdnwgppabwp@gmail.com</i></td></tr>
 
 </table>
 </form>

';

my $srch=lc($V::CGI{search});
 $srch =~ s/\'/\'\'/g;
  $srch =~ s/\s//g;
if($srch !~/\@/){
  print "$res<hr><i>введите адрес получателя.</i>";
  return 1;
}
my $sql = "select 
  l.int_id,
  l.created,
  l.str,
  m.created,
  m.str,
  extract(EPOCH from l.created),
  extract(EPOCH from m.created),
  m.id
 from log l 
  left join message m  on m.int_id=l.int_id
 where l.address='$srch'";
 
 # print "$sql <hr>";
  my $list = $V::T{DB}->GetItems($sql);

 my %H=();
 my %IN=();
 my $k=0;
 ## заполняем хеш найденными данными 
 for my $i(0..$#{$list}){
   push(@{$H{$list->[$i][0]}},[$list->[$i][5],$list->[$i][1],$list->[$i][2]]);
   $k++;
   if(!$IN{$list->[$i][7]} && $list->[$i][7]){
     push(@{$H{$list->[$i][0]}},[$list->[$i][6],$list->[$i][3],$list->[$i][4]]);
     $IN{$list->[$i][7]}=1; # не дублируем message
     $k++;
    }
 }
%IN=(); #чистим флаги 

 my $msg;
 if($k>100){
   $msg = "<br><font color=red>Показаны первые 100 записей</font>";
 }
 $res .="<b>Всего найдено: $k </b>$msg<hr><table col><tr><td>N</td><td>Дата</td>
 <td>Строка лога </td>
 </tr>";
 my $i=1;
 foreach my $int_id (sort{ $a cmp $b} keys %H){
   foreach my $row (sort{$a->[0] <=> $b->[0]} @{$H{$int_id}} ){
     my $bg;
     if($i/2==int($i/2)){ $bg=" bgcolor=#eeeeee";}
      $res .="<tr$bg><td>$i</td>
      <td>$$row[1]</td>
      <td>$$row[2]</td>
       </tr>";
       $i++;
       if($i>100){last}
   } 
   if($i>100){last}
}
$res .="</table>";
Z::out $res;

return 1;
}

sub head{
 Z::out <<"EOF";
<!DOCTYPE html>
<html>
  <head>
  <title>IT ONE test</title>
 
  <style type="text/css">
p {
  font-style: italic;
}
table td, table th {
    padding: 5px;
}
</style>
  </style>
  </head>
 <body>
 <a href=/Task.pdf>Task.pdf</a>
 <hr>
EOF

return 1;
}

sub footer{
  Z::out <<"EOF";
  <br><br>
  <hr>
    <br><br>
  </body></html>
  
EOF

return 1;
}
