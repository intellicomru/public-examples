
## переименование fb2 файлов для андроида (линукса)
## find . -name "*.fb2"  -exec perl ./rename_fb2.pl {} \;

use strict;
use utf8;
use XML::TreePP;
#use uni::perl   qw| :dumper |;
use Encode qw( decode_utf8 encode_utf8 );
no warnings 'layer';

my $path=$ARGV[0];
unless(-f $path){ print "No file $path \n"; exit }
 my $tpp = XML::TreePP->new();

 my $xml = $tpp->parsefile( $path );
 my $root = $xml->{ ( keys %{$xml} )[0] }->{description}{'title-info'};


 
  my $fname = $root->{author}{ "first-name"};
  my $lname = $root->{author}{ "last-name"};
  my $title = $root->{ "book-title"};
  
  my $new_filename="$lname $fname - $title.fb2";
  print "RENAME: ".decode_utf8($path)." -> ".decode_utf8($new_filename)."\n";
  
  rename($path, $new_filename)