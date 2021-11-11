#!/usr/local/bin/perl
use Benchmark qw( timethese cmpthese ) ;
use Time::HiRes;
use strict;

my $StartTimeHiRes=[Time::HiRes::gettimeofday()];    # Точное время старта 

our $cnt=0;
my @big_massiv=(0,22,33);
for my $dd (0..1000000){
   push(@big_massiv,int(rand(1000000)));
};
my @big_mass = sort {$a <=>$b }@big_massiv;
@big_massiv =();
#print join(",",@big_mass)."\n";
my $dig=6463;
my $StartDi=[Time::HiRes::gettimeofday()];    # Точное время старта 
my $index;
## проверяем что число внутри диапозона
if($dig<$big_mass[0]){  $index= $big_mass[0]}
elsif($dig>$big_mass[$#big_mass]){$index= $big_mass[$#big_mass]; }
else{
## находим нужный элемент. заодно замеряем нагрузку на статичном массиве 
 my $r = timethese( -5, {
    DiggInArray => sub{ $index=get_index($dig,\@big_mass,0,$#big_mass); print "RESULT: $dig near ".$big_mass[$index]."  [index = $index]  \n"; $cnt=0;}
} );
 cmpthese $r;
}
 print "Time to search: ".sprintf("%.10f",Time::HiRes::tv_interval($StartDi))."\n";
 print "Time to work: ".sprintf("%.10f",Time::HiRes::tv_interval($StartTimeHiRes))."\n";
  
  
sub get_index{
 my $dig=shift;
 my $arr=shift;
 my $index=int(shift);
 my $leng=int(shift);
 my $len = $index+$leng;
# print $$arr[$index]." <  $dig < ".$$arr[$len]."\n";
 $cnt++; ## защита от бесконечной рекурсии
# print "$cnt. ";
  if($cnt>1000){ return }
## граничные условия 
if($$arr[$index]==$dig ){ return $index}
if($$arr[$len]==$dig ){ return $len}
 my $half_len=int($leng/2);
my $i_half=$index+$half_len;
if($$arr[$i_half]==$dig ){ return $i_half}

## индексы рядом значит выбираем один из них 
if($len == $index+1){
    return  ($$arr[$index]-$dig)**2 >= ($$arr[$len]-$dig)**2 ?  $len : $index; 
}
 if($$arr[$index]<$dig &&  $$arr[$i_half]>$dig){
    $index= get_index($dig,$arr,$index,$half_len);
 }else{
   $index= get_index($dig,$arr,$i_half,$half_len);
 }
return $index;
}