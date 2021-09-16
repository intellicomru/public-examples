#!/usr/local/bin/perl

=head
« скрипт, получающий в качестве параметра путь к XML-файлу и выдающий на STDOut следующее:
Суммарное число букв внутри тегов, не включая пробельные символы (<aaa dd="ddd">text</aaa> - четыре буквы)
Суммарное число букв нормализованного текста внутри тегов, включая и пробелы
Число внутренних ссылок (теги <a href="#id">)
Число битых внутренних ссылок (ссылки на несуществующие ID элементов)
=cut

use strict;
use utf8;
use open qw(:std :utf8);

my $file=$ARGV[0];
unless(-f $file){
  print "No such file: $file \n";
  exit; 
}
my $sk=$ARGV[1];
open(F,$file) || die "Can't open file $file \n $!\n";
my @res=<F>;
close F;

my %H=();
my $ures= join(" ",@res);

get_stat(\%H,$ures);
# пишем ответы : 
print "файл $file содержит \n";
print "Суммарное число букв внутри тегов, не включая пробельные символы: ".split_didgit($H{len_1})." \n";
print "Суммарное число букв нормализованного текста внутри тегов, включая и пробелы: ".split_didgit($H{len_2})." \n";
print "Число внутренних ссылок : $H{cnt_akeys_dbl} \n";
print " - уникальных ключей внутренних ссылок : $H{cnt_akeys} \n";
print "Число битых внутренних ссылок : $H{cnt_bad_links} \n";
print " - уникальных битых ключей внутренних ссылок : $H{cnt_bad_keys} \n";
if($sk){
 print "Битые ключи:\n";
  foreach my $key (keys %{$H{bad_akeys}{bkey}}){
          print "$key | встречается ".$H{bad_akeys}{bkey}{$key}." раз \n";
     }  
}
sub get_stat{
  my $H=shift;
  my $res=shift;
  # избавляемся от тегов - оставляем только чистый текст без пробелов. знаки припинания тоже считаем как символы.   
    my $clear_data=$res;
    my $k=1;
     while($clear_data =~s/\<binary [^>]+\>([^<]+)<\/binary>//g) {# чистим картинки
        $$H{"img_".$k}=$1;
     }
     /()/;
     # чистим от тегов
    $clear_data =~ s/<[^>]+>//g;
    my $normal_data=$clear_data;
     # удаляем пробелы и считаем
    $clear_data  =~ s/\s//g;
    $$H{len_1}=length($clear_data);
 #   print "len1=".$$H{len_1}."\n";
      # нормализуем текст и считаем 
     $normal_data=lc($normal_data);
     $normal_data =~s/[^а-яa-z\d]/ /g;
     $normal_data =~s/\s+/ /g;
     $normal_data =~s/^\s+|\s+$//;
     $$H{len_2}=length($normal_data);
  #  print "len2=".$$H{len_2}."\n";
    
    # разбираемся с ссылками 
    ## собираем 
     while( $res =~/<a .*?href\=\"\#([^\"]+)\"/ig){
         $$H{akeys}{$1}++;
      #   print "akey=".$1." | ";
     }
     # считаем как уникальные так и просто все встречающиеся. 
     $$H{cnt_akeys}=scalar keys %{$$H{akeys}}; # количество уникальных ссылок
     foreach my $akey  (keys %{$$H{akeys}}){
       $$H{cnt_akeys_dbl}+=$$H{akeys}{$akey};
       #print "$akey=".$$H{akeys}{$akey} if $$H{akeys}{$akey}>1 ;
     }
     
    # print "H{cnt_akeys}=$$H{cnt_akeys} | H{cnt_akeys_dbl}=$$H{cnt_akeys_dbl}\n";
     while( $res =~/<section .*?id\=\"([^\"]+)\"/ig){
         $$H{skeys}{$1}=1;
      #   print "skey=".$1." | ";
     }
     # считаем битые ссылки 
    foreach my $key (keys  %{$$H{akeys}}){
       if(!int($$H{skeys}{$key})){
          $$H{bad_akeys}{cnt_in}++;
          $$H{bad_akeys}{bkey}{$key}=$$H{akeys}{$key};
       }
    }
   #print "bad keys=".$$H{bad_akeys}{cnt_in}."\n";
    if($$H{bad_akeys}{cnt_in}){
      $$H{cnt_bad_keys}=scalar keys %{$$H{bad_akeys}{bkey}};
      #print "H{cnt_bad_keys}=$$H{cnt_bad_keys}\n";
       foreach my $key (keys %{$$H{bad_akeys}{bkey}}){
          $$H{cnt_bad_links}+=$$H{bad_akeys}{bkey}{$key};
       #   print "$key (".$$H{bad_akeys}{bkey}{$key}.") | ";
        }  
    }
return 1;
}

sub split_didgit{
my $t=int(shift);
my $k=length($t);
my @res;
for my $i (1..$k){
   push(@res,substr($t,-$i,1));
   if($i && $i/3==int($i/3)){push(@res,' ');}
}
return join('',reverse(@res));
}