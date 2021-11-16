package mydb;

use uni::perl qw| :dumper |;
use utf8;
use DBI;
use Time::HiRes;

use Config2;
 
sub new {  
 my ( $class, $config,$dbname ) = @_;
    my $self = bless {}, $class;
    if($config){
      $self->{'config'}=$config;
    }else{
    	my $project =  'admin'; 
      $config = Admin::Config2->new('project' => $project ); 
      $self->{'config'}=$config;
    }
    unless($dbname){
    	 $self->{db}=$config->{'DB'};
    }else{
       $self->{db}=$config->{$dbname};
    }
    $self->{'Time'} =time;
  
     $self->ConnectDB;
     return $self;
 }

########### Функции обращения к базам данных
#  
###########
#   Функция получения записей из базы данных: GetItems ($self,$query);
#   возвращает ссылку на массив ссылок на записи, если операция успешна.
#   Пример:
#   my $table=$self->GetItems("SELECT * FROM newslist");
#   for my $i ( 0 .. $#{$table} ) {
#     for my $j ( 0 .. $#{$table->[$i]} ) {
#         print "$table->[$i][$j] ";
#         }
#      print "\n";
#     }
sub GetItems {
  my($self,$query)=@_;
 
  return unless $self->ConnectDB;
  
  my $sth;
  unless($sth=$self->{dbh}->prepare($query)) {
  	  db_log($self->{db},"prepare",$self->{dbh}->errstr,$query); return;
      }
  unless($sth->execute) {
	  db_log($self->{db},"execute",$sth->errstr,$query); return;
      }
  my $table;
  if($query !~/^insert/i){
   unless($table=$sth->fetchall_arrayref) {
    	db_log($self->{db},"fetchall_arrayref",$sth->errstr,$query); return;
    }
  }elsif($query =~/\sRETURNING\s/i){
  	$table=$sth->fetchall_arrayref;
  }  
  $sth->finish;
  return $table;      
}
#
###########
#   Выполняет SQL команду: DO(@commands);
#   возвращает результат SQL-команды, если операция успешна. 

sub DO {
  my($self,@commands)=@_;
  return unless $self->ConnectDB; 
  my $result;
  unless($result=$self->{dbh}->do(@commands)) {
   	db_log($self->{db},"@commands",$self->{dbh}->errstr,"@commands"); return;
   	} 
  return $result; 
}	
###########
#   Выполняет SQL команду: INSERT 
#   возвращает результат SQL-команды, если операция успешна. 
# 
sub insert {
 my($self,$table,$refH,$refA,$param,$ret)=@_;
 my $cols=join(',',@$refA);
 my $vals=H_to_Ains($refH,$refA);
 #print "INSERT $param INTO $table ($cols) VALUES($vals) $ret";
 return $self->GetItems("INSERT $param INTO $table ($cols) VALUES($vals) $ret");
}
#
sub update {
 my($self,$table,$refH,$refA,$where,$param)=@_;
 my $S=H_to_Aset($refH,$refA);
 return $self->DO("UPDATE $param $table SET $S WHERE $where");
}
#
sub get_one {
 my($self,$table,$refH,$refA,$where)=@_;
 my $sel=join(',',@$refA);
 my $t=$self->GetItems("SELECT $sel FROM $table WHERE $where");
 A_to_H($refH,$refA,$t->[0]) if defined $t->[0];
 return $t->[0];
}
#
sub get_many {
 my($self,$table,$refH,$refA,$where,$par,$print_sql)=@_;
 my $sel=join(',',@$refA);
 print "SELECT $par $sel FROM $table WHERE $where" if $print_sql;
 my $t=$self->GetItems("SELECT $par $sel FROM $table WHERE $where");
 my $quant=0;
 if(defined $t) { 
	for my $i ( 0 .. $#{$t} ) {
	  A_to_H_as_A($refH,$refA,$t->[$i]);	$quant++;
	}
 }
 return $quant;
}
#  Функция возвращает сылку на массив содержащий поля таблици
#  get_columns_array($schema,$table,$flag) ;
#  $table - таблица
#  $flag - флаг указывающий как возвращать названия полей
#  (0 - поле,1- таблица.поле)
#    Пример:
#     my $A=get_columns_array("contact","items");
# ...get_one("contact.items",\%H,$A,$where);
# SELECT column_name FROM information_schema.columns WHERE TABLE_SCHEMA='contract' and table_name ='items';
sub get_columns_array{
	my ($self,$schema,$table,$flag,$me)=@_;
	return if (!$schema || !$table);
	my $columns=$self->GetItems("SELECT column_name FROM information_schema.columns WHERE TABLE_SCHEMA='$schema' and table_name ='$table'");
	my @A=();
   	 if(!$me){ $me=$schema.".".$table; }
	for my $i (0..$#{$columns}){
  	 my $column;
  	 if($flag){
   		 $column=$me.".".$columns->[$i][0]
   		}else{$column=$columns->[$i][0]}                       
   	push(@A,$column);
	}
return \@A;
}  

###########################################
#### Внутренние функции модуля,
#### к ним не требуется обращаться напрямую.
##############
#   Соединение с хэшированием и проверкой (живо ли оно?).
#   ConnectDB();
sub ConnectDB {
 my $self=shift;
 my $src_dsn = $self->{db}{'connect_info'};
  if($self->{dbh}) {
     if($self->{dbh}->ping) { return 1; }
			    else {$self->{dbh}->disconnect; }
     }

  unless($self->{dbh}=DBI->connect( @$src_dsn[0..3])) {
      db_log($self->{db},"connect","$DBI::errstr"); 
      delete($self->{dbh});	
      return;
      }
  
  return 1;
}

sub disconnectDB {
  my $self=shift;
  if($self->{dbh}) {
			   $self->{dbh}->disconnect; 
     }  
  return 1;
}
### функции преобразования массивов в хеши и наоборот по МАССИВУ КЛЮЧЕЙ @K
### A_to_H(\%H,\@K,\@V); Array to Hesh (результат %H)
sub A_to_H {
  my ($H,$K,$V)=@_;		#ссылки
  for(my $i=0;$i<=$#$K;$i++) { $$H{$$K[$i]}=$$V[$i]; }
}	
### H_to_A(\%H,\@K,\@V);  Hesh to Array (результат @V)
sub H_to_A {
  my ($H,$K,$V)=@_;		#ссылки
  for(my $i=0;$i<=$#$K;$i++) { push(@$V,$$H{$$K[$i]}); }
}
### H_to_Aset(\%H,\@K);  Hesh to S for SET (результат строка)
sub H_to_Aset {
  my ($H,$K)=@_;		#ссылки
  my $S;
  foreach (@$K) { $S.="$_=\'$$H{$_}\',"; }
  $S=~s/\,$//o;
  return $S;
}
### H_to_Ains(\%H,\@K);  Hesh to S for INS (результат строка)
sub H_to_Ains {
  my ($H,$K)=@_;		#ссылки
  my $S;
  foreach (@$K) { $S.="\'$$H{$_}\',"; }
  $S=~s/\,$//o;
  return $S;
}

### Добавляем в хэш много величин ($H{key1}->[$i])
###A_to_H_as_A
sub A_to_H_as_A {
  my ($H,$K,$V)=@_;		#ссылки
  for(my $i=0;$i<=$#$K;$i++) { push(@{$$H{$$K[$i]}},$$V[$i]); }
}	
#
### Берем срез от сложного хэша ссылок к простому хэшу
sub face {
  my($ref,$i)=@_;
  my %H;
  while(my($k,$v)=each %$ref) { $H{$k}=${$v}[$i]; }
  return \%H;
}
###
###
sub ch_for_db {
	my $v=shift;
	$v=~s/\\/\\\\/go;
	$v=~s/\'/\'\'/go;
	return $v;
}
###
sub cleare_row{
 my $self=shift; 	
 my $H=shift;
 foreach my $key (keys %{$H}){
   $$H{$key}=ch_for_db($$H{$key});
 }
 return 1;
 }
sub db_log{
 my ($self,$db,$sql_type,$err)=@_;
 
return 1;	
}


1;