#!/usr/bin/perl

use lib::abs    qw| ../pm . |;
use uni::perl   qw| :dumper |;

use utf8;
use Time::HiRes;
use Admin::pm::Vars;
use English;
use Encode qw( decode_utf8 encode_utf8 );
use V;
use File::Basename;
use File::Path qw( make_path );
use mydb;
use util;
use Config2;
use POSIX qw(strftime);
use GetURI;
use JSON qw(to_json from_json);
use URI::Escape qw(uri_escape_utf8);
use XML::TreePP;
use LWP::UserAgent;
use XML::Entities;

binmode(STDOUT,':utf8');

	### все переменные собраны тут 
 $ENV{CONFIG_DIR}='';
 $ENV{CONFIG_PROJECT}='';
 V::InitGlobal();
 $V::T{config_dir}='/tmp/'; 
 $V::T{config_project}='test' ;

 $V::T{CONFIG}=Admin::Config2->new( 'dir'=>$V::T{config_dir}, 'project' => $V::T{config_project} );
$V::T{DB} = "db";
 $V::T{DB}=mydb->new($V::T{CONFIG},$V::T{DB});
 ####
 ## обработка XML 
  my $url="http://ddex.com/example.xml";
  parse_xml();
  
 ### функция парсинга XML 	
 sub parse_xml{	
  my $url=shift || return; 
  ####  
  my $uri=Admin::pm::GetURI->new();
  print "URL: $url \n";
  my $xml_src=$uri->get_url($url);
 
  my %Tracks=();
  my %Relise=();
  my %Hk=();
  my %H=();
  my $tpp = XML::TreePP->new();

  #my $xml = $tpp->parsefile( $path );
 
  my $xml = $tpp->parse($xml_src);
  my $root = $xml->{ ( keys %{$xml} )[0] };
  $V::T{MessageCreatedDateTime}=$root->{MessageHeader}{MessageCreatedDateTime};
  my ( $main_release, @track_releases ) = parse_releases( $root );
 #print dumper $main_release;

 foreach my $trelease ( @track_releases ) {
	 my $release_reference = $trelease->{ReleaseResourceReferenceList}{ReleaseResourceReference}{"#text"};
    $H{$trelease->{ReleaseReference}}=$release_reference;
    $Relise{$release_reference} = {
        grid              => $trelease->{ReleaseId}{GRid},
        isrc              => $trelease->{ReleaseId}{ISRC} || get_isrc_from_ProprietaryId( get_ProprietaryId( $trelease->{ReleaseId}{ProprietaryId} ) ),
        proprietary_id    => get_ProprietaryId( $trelease->{ReleaseId}{ProprietaryId} ),
        external_id       => determine_release_external_id( $trelease ),
        name_orig              => $trelease->{ReferenceTitle}{TitleText} ,
        json_custom_track       => to_json( $trelease ),
        release_reference => $trelease->{ReleaseReference},
        year=>$trelease->{Release}{PLine}{Year}
    };
    foreach my $trow ( @{to_arrayref($trelease->{ReleaseDetailsByTerritory})} ){
    	
     if( $trow->{DisplayArtist}){
     	 my @pmfrs;
     	  ### автор - композитор
        my @autors;
       my @composit;
     	 foreach my $DA_row ( @{to_arrayref($trow->{DisplayArtist})}){
     	 	#if($DA_row->{ArtistRole} && $DA_row->{ArtistRole} ne "MainArtist"){ next }
     	 	  my $fio;
     	  	foreach my $paty (@{to_arrayref($DA_row->{PartyName})}){
     	  		  #print dumper $paty;
     	  		  if(ref $paty->{FullName} eq 'HASH'){
     	  		  	unless($paty->{FullName}{"-LanguageAndScriptCode"}){
     	  	       # push(@pmfrs,$paty->{FullName});
     	  	       $fio .=", " if $fio;
     	  	       $fio .=$paty->{FullName}{"#text"};
     	  	      }
     	  		  }else{
     	 		     unless($paty->{"-LanguageAndScriptCode"}){
     	  	       # push(@pmfrs,$paty->{FullName});
     	  	       $fio .=", " if $fio;
     	  	       $fio .=$paty->{FullName};
     	  	     }
     	  	   }    
         }
         if($fio){
         	### автор - композитор - исполнитель 
         	#print dumper  $DA_row->{ArtistRole};
     	 	  foreach my $role (@{to_arrayref($DA_row->{ArtistRole})}){
     	 	  	 #print "role: $role\n";
     	 	     	if($role =~/Composer/i){
     	 	     		 push(@composit,$fio);
     	 	     	}
     	 	      if($role =~/Lyricist/i || $role=~/Author/i ){
     	 	     		 push(@autors,$fio);
     	 	     	}
     	 	     	if($role =~/MainArtist/i){
     	 	     		 
     	 	     		 push(@pmfrs,$fio);
     	 	     	}
     	 	  }
     	 	 } 
       }
        $Relise{$release_reference}->{author_text} = join(", ",@autors);
        $Relise{$release_reference}->{author_music} = join(", ",@composit);
        $Relise{$release_reference}->{performers} = join(", ",@pmfrs);
       # print "performers:".$Relise{$release_reference}->{performers}."\n";
     }
     if(!$Relise{$release_reference}->{performers} && $trow->{DisplayArtistName}){
       $Relise{$release_reference}->{performers}=$trow->{DisplayArtistName};
     }
    } 
 #  print $Relise{$release_reference}->{performers}."\n";
    # performers=>$trelease->{ReleaseDetailsByTerritory}{DisplayArtistName},
   # print dumper $track_release_params;
 }
 
my @SoundRecording =  @{to_arrayref($root->{ResourceList}{SoundRecording})} ;
#print dumper \@SoundRecording;
my $k=0;
 foreach my $trelease ( @SoundRecording ) {
 	 $k++;
 	# print "++ $k ++ \n";
 	  my $release_reference = $trelease->{ResourceReference};
 	 # print "release_reference=$release_reference\n";
 	  my $territor=parse_releases_by_territory($trelease);
 	 # print "SoundRecordingDetailsByTerritory : \n".dumper($trelease);
  $Tracks{$release_reference}->{WorkListID}= $trelease->{ResourceMusicalWorkReferenceList}{ResourceMusicalWorkReference}{ResourceMusicalWorkReference};
 	
 	  my @performers = @{ to_arrayref($trelease->{ReleaseDetailsByTerritory}{DisplayArtist}) };
 	  my @pmfrs;
 	  # print dumper @performers;
 	 if($#performers>=0){
     foreach my $perf (@performers){
    	# print dumper $perf;
    	foreach my $paty (@{to_arrayref($perf->{PartyName})}){
     	  		  #print dumper $paty;
     	  		  if(ref $paty->{FullName} eq 'HASH'){
     	  		  	unless($paty->{FullName}{"-LanguageAndScriptCode"}){
     	  	       push(@pmfrs,$paty->{FullName});
     	  	      }
     	  		  }else{
     	 		     unless($paty->{"-LanguageAndScriptCode"}){
     	  	        push(@pmfrs,$paty->{FullName});
     	  	     }
     	  	   }    
         }
    	}
    }else{
       ## пробуем искать в др. блоке 	
     if(ref $trelease->{SoundRecordingDetailsByTerritory} eq 'HASH'){
    	@performers = @{ to_arrayref($trelease->{SoundRecordingDetailsByTerritory}{DisplayArtist}) } ;
    	#print dumper $trelease->{SoundRecordingDetailsByTerritory};
    	foreach my $perf (@performers){
    	 # print dumper $perf;
    	  foreach my $paty (@{to_arrayref($perf->{PartyName})}){
     	  		  #print dumper $paty;
     	  		  if(ref $paty->{FullName} eq 'HASH'){
     	  		  	unless($paty->{FullName}{"-LanguageAndScriptCode"}){
     	  	       push(@pmfrs,$paty->{FullName});
     	  	      }
     	  		  }else{
     	 		     unless($paty->{"-LanguageAndScriptCode"}){
     	  	        push(@pmfrs,$paty->{FullName});
     	  	     }
     	  	   }    
         }
    	}
     }	
    }	
    
    $Tracks{$release_reference}->{performers} = join(", ",@pmfrs) unless $Tracks{$release_reference}->{performers};
    $Tracks{$release_reference}->{grid} = $trelease->{SoundRecordingId}{GRid};
    $Tracks{$release_reference}->{isrc} = $trelease->{SoundRecordingId}{ISRC} || get_isrc_from_ProprietaryId( get_ProprietaryId( $trelease->{SoundRecordingId}{ProprietaryId} ) );
    $Tracks{$release_reference}->{proprietary_id} = get_ProprietaryId( $trelease->{SoundRecordingId}{ProprietaryId} );
    $Tracks{$release_reference}->{external_id} = determine_release_external_id( $trelease );
    $Tracks{$release_reference}->{name_orig} = $trelease->{ReferenceTitle}{TitleText} ;
    $Tracks{$release_reference}->{json_custom_sound} = to_json( $trelease );
    $Tracks{$release_reference}->{resource_reference} = $trelease->{ResourceReference};
    foreach my $SDT_row (@{to_arrayref($trelease->{SoundRecordingDetailsByTerritory})}){
      $Tracks{$release_reference}->{year} = $SDT_row->{PLine}{Year} if $SDT_row->{PLine}{Year} ;
      $Tracks{$release_reference}->{territory} .= join(",",@{to_arrayref($SDT_row->{TerritoryCode})}).";" ; 
      $Tracks{$release_reference}->{publisher} .= $SDT_row->{PLine}{PLineText}.";" if  $SDT_row->{PLine}{PLineText};
      $Tracks{$release_reference}->{genre}=$SDT_row->{Genre}{GenreText} if $SDT_row->{Genre}{GenreText};
      ### автор - композитор ищем в другом блоке если он есть 
      my @autors;
      my @composit;
      foreach my $roles (@{to_arrayref($SDT_row->{IndirectResourceContributor})}){
      	 #print dumper $roles;
      	  my $fio;
      		foreach my $cname (@{to_arrayref($roles->{PartyName})}){
      			unless($cname->{"-LanguageAndScriptCode"}){
      			  $fio .=", " if $fio;
         	    $fio .= $cname->{FullName};
         	  }  
         	 } 
         if($fio){	 
         	if(ref $roles->{IndirectResourceContributorRole} eq 'HASH'){
         	  if($roles->{IndirectResourceContributorRole}{"-UserDefinedValue"} =~/Writer/i){
         		  push(@autors,$fio);
         		}
         		if($roles->{IndirectResourceContributorRole}{"-UserDefinedValue"} =~/Composer/i){
         		  push(@composit,$fio);
         		}
         	}else{
         	 foreach my $lrol (@{to_arrayref($roles->{IndirectResourceContributorRole})}){
      		      if($lrol =~/Composer/i){
         	 				push(@composit,$fio);
         	 		  }
         	 		  if($lrol =~/Author/i || $lrol =~/Lyricist/i){
         	 				push(@autors,$fio);
         	 		  }
         	 } 		  		
          }
        }
       }
       $Tracks{$release_reference}->{author_text} .= join(",",@autors) ; 
       $Tracks{$release_reference}->{author_music} .= join(",",@composit) ; 
      #if($Tracks{$release_reference}->{year}){ last }
    $Tracks{$release_reference}->{duration} = $trelease->{Duration};
    foreach my $TSRD_row (@{to_arrayref($SDT_row->{TechnicalSoundRecordingDetails})}){
    	# print dumper $TSRD_row;
     if($TSRD_row->{File}{IsPreview} eq 'true'){ print "IsPreview - skeep\n"; next }
     if($TSRD_row->{AudioCodecType} =~ /MP3/i || $TSRD_row->{AudioCodecType} =~ /FLAC/i){
        $Tracks{$release_reference}->{filename} = $TSRD_row->{File}{FileName};
        $Tracks{$release_reference}->{filepath} = $TSRD_row->{File}{FilePath};
        $Tracks{$release_reference}->{URL} =  $TSRD_row->{File}{URL};
        $Tracks{$release_reference}->{md5} = $TSRD_row->{File}{HashSum}{HashSum};
        last;
      }elsif(!$TSRD_row->{AudioCodecType} && !$Tracks{$release_reference}->{filename}){
        $Tracks{$release_reference}->{filename} = $TSRD_row->{File}{FileName};
        $Tracks{$release_reference}->{filepath} = $TSRD_row->{File}{FilePath};
        $Tracks{$release_reference}->{URL} =  $TSRD_row->{File}{URL};
        $Tracks{$release_reference}->{md5} = $TSRD_row->{File}{HashSum}{HashSum};
      }elsif(!$Tracks{$release_reference}->{filename}){
        $Tracks{$release_reference}->{filename} = $TSRD_row->{File}{FileName};
        $Tracks{$release_reference}->{filepath} = $TSRD_row->{File}{FilePath} ;
        $Tracks{$release_reference}->{URL} =  $TSRD_row->{File}{URL};
        $Tracks{$release_reference}->{md5} = $TSRD_row->{File}{HashSum}{HashSum};	
      }
    }
   }

   # print dumper $track_release_params;
 }
 
 ## ищем доли авторских и смежных прав там где их передают 
 ### worklist 
 my @WorkList =  @{to_arrayref($root->{WorkList}{MusicalWork})} ;
#print dumper \@WorkList;
 my %WL=();
 foreach my $wlist ( @WorkList ) {
   my $release_reference = $wlist->{MusicalWorkReference};
 	 $WL{$release_reference}->{json_worklist} = to_json( $wlist );
 	 foreach my $wrights (@{to_arrayref($wlist->{RightShare})}){
 	   foreach my $wrc (@{to_arrayref($wrights->{RightsController})}){
 	   	  $WL{$release_reference}{roles}{$wrc->{RightsControllerRole}}{persent}=$wrc->{RightSharePercentage};
 	      $WL{$release_reference}{roles}{$wrc->{RightsControllerRole}}{name}=$wrc->{PartyName}{FullName};
 	    } 
 	  }  
  }
 
 #print dumper $main_release->{ReleaseId};

foreach my $ReleaseResourceReference (@{to_arrayref($main_release->{ReleaseResourceReferenceList}{ReleaseResourceReference})}){
	  my $id;
	  if(ref($ReleaseResourceReference) eq 'HASH'){
	    $id=$ReleaseResourceReference->{"#text"};
	  }elsif($main_release->{ReleaseId}{ICPN}){
	  	$id=$ReleaseResourceReference;
	  }
	  if(ref($main_release->{ReleaseId}{ICPN}) eq 'HASH'){
	    $Tracks{$id}{icpn}=$main_release->{ReleaseId}{ICPN}{"#text"};
	  }elsif($main_release->{ReleaseId}{ICPN}){
	  #	print "ref ICPN =".ref($main_release->{ReleaseId}{ICPN})."\n";
	  	$Tracks{$id}{icpn}=$main_release->{ReleaseId}{ICPN};
	  }
	  if(ref($main_release->{ReleaseId}{CatalogNumber}) eq 'HASH'){
	    $Tracks{$id}{CatalogNumber}=$main_release->{ReleaseId}{CatalogNumber}{"#text"};
	  }elsif($main_release->{ReleaseId}{CatalogNumber}){
	  	$Tracks{$id}{CatalogNumber}=$main_release->{ReleaseId}{CatalogNumber};
	  }
	  $V::T{main_GRid}=$main_release->{ReleaseId}{GRid} if $main_release->{ReleaseId}{GRid};
	  $Tracks{$id}{album_name}=$main_release->{ReferenceTitle}{TitleText};
	  $Tracks{$id}{json_main_release}=to_json($main_release->{ReleaseId});
	}
 ## права 
 my @ReleaseDeal =  @{to_arrayref($root->{DealList}{ReleaseDeal}) };
 my %Prava=();
 foreach my $trelease ( @ReleaseDeal ) {
 	  foreach my $release_reference ( @{to_arrayref($trelease->{DealReleaseReference})} ){
 	   my @Deal=@{to_arrayref($trelease->{Deal})};
     #  print dumper $Deal[0]{DealTerms};
     $Prava{$H{$release_reference}}{prava_from} = $Deal[0]{DealTerms}{ValidityPeriod}{StartDateTime} || $Deal[0]{DealTerms}{ValidityPeriod}{StartDate};
     $Prava{$H{$release_reference}}{prava_to} = $Deal[0]{DealTerms}{ValidityPeriod}{EndDateTime} || $Deal[0]{DealTerms}{ValidityPeriod}{EndDate};
     $Prava{$H{$release_reference}}{json_custom_prava} =  to_json( $trelease );
     $Prava{$H{$release_reference}}{dealreleasereference} = $release_reference;
   } 
 }
 
 ### проверяем информацию о картинке/ках
 my @Image =  @{to_arrayref($root->{ResourceList}{Image})} ;
 my %IMG=();
 my $k=1;
  foreach my $irelease ( @Image ) {
  	#print dumper $irelease;
  	 my $release_reference = $irelease->{ResourceReference} || $k;
  	 $IMG{$release_reference}{row_num}=$release_reference;
  	 $IMG{$release_reference}{json_custom}=to_json($irelease);
    if(ref($irelease->{ImageId}{ProprietaryId}) eq 'HASH'){
	    $IMG{$release_reference}{external_id}=$irelease->{ImageId}{ProprietaryId}{"#text"};
	  }elsif($main_release->{ReleaseId}{ICPN}){
	  	$IMG{$release_reference}{external_id}=$irelease->{ImageId}{ProprietaryId};
	  }
	  $IMG{$release_reference}{imagetype}=$irelease->{ImageType};
	  ## кто то передает массивом 
	  my @ImageDetailsByTerritory =  @{to_arrayref($irelease->{ImageDetailsByTerritory})} ;
	  foreach my $rel_TDT (@ImageDetailsByTerritory){
	  ## высота картинки 
	  if(ref($rel_TDT->{TechnicalImageDetails}{ImageHeight}) eq 'HASH'){
	  	$IMG{$release_reference}{imageheight}=$rel_TDT->{TechnicalImageDetails}{ImageHeight}{"#text"};
	  }else{
	  	$IMG{$release_reference}{imageheight}=$rel_TDT->{TechnicalImageDetails}{ImageHeight}
	  }
	  ## ширина картинки 
	  if(ref($rel_TDT->{TechnicalImageDetails}{ImageWidth}) eq 'HASH'){
	  	$IMG{$release_reference}{imagewidth}=$rel_TDT->{TechnicalImageDetails}{ImageWidth}{"#text"};
	  }else{
  	 $IMG{$release_reference}{imagewidth}=$rel_TDT->{TechnicalImageDetails}{ImageWidth};
	  }
  	 $IMG{$release_reference}{imagecodectype}=$rel_TDT->{TechnicalImageDetails}{ImageCodecType};
  	 $IMG{$release_reference}{filename}=$rel_TDT->{TechnicalImageDetails}{File}{FileName};
  	 $IMG{$release_reference}{path_to_file}=$rel_TDT->{TechnicalImageDetails}{File}{FilePath};
  	 $IMG{$release_reference}{md5}=$rel_TDT->{TechnicalImageDetails}{File}{HashSum}{HashSum};
  	 my @terr= @{to_arrayref($rel_TDT->{TerritoryCode})} ;
  	 foreach my $iterr ( @terr ) {
  	 	  $IMG{$release_reference}{territoria} .= ", " if $IMG{$release_reference}{territoria};
  	  	$IMG{$release_reference}{territoria} .= $iterr;
  	 }
  	 ## Title картинки 
  	 my @title= @{to_arrayref($rel_TDT->{Title})} ;
  	 foreach my $itit ( @title ) {
  	 	if(ref($itit) eq 'HASH'){
  	 		if($itit->{"-TitleType"} eq 'DisplayTitle'){
	  	   $IMG{$release_reference}{title}=$itit->{TitleText};
	  	  }
	    }else{
	    	$IMG{$release_reference}{title} .="' " if $IMG{$release_reference}{title};
  	    $IMG{$release_reference}{title} .=$$itit;
	    }
  	 }
  	} 
  	 $k++;
  }	
  print dumper \%IMG;
  foreach my $ikey(keys %IMG){
   my %IH=();
   foreach my $ivals (keys %{$IMG{$ikey}}){
   	  $IH{$ivals}=decode_utf8($IMG{$ikey}{$ivals});
   	}	
   	$IH{catalog_id}=$V::T{Catalog_id};
   	$IH{file_id}=$uuid;
   my @A=keys %IH;
   clear_row(\%IH);  
   print dumper \%IH; 
   next unless $IH{filename};
 
  }
 
 #### собираем данные о txt pdf файлах  
 my @Texts =  @{to_arrayref($root->{ResourceList}{Text})} ;
 my %TXT=();
 my $k=1;
  foreach my $irelease ( @Texts ) {
  	#print dumper $irelease;
  	 my $release_reference = $irelease->{ResourceReference} || $k;
  	 $TXT{$release_reference}{row_num}=$release_reference;
  	 $TXT{$release_reference}{json_custom}=to_json($irelease);
    if(ref($irelease->{TextId}{ProprietaryId}) eq 'HASH'){
	    $TXT{$release_reference}{external_id}=$irelease->{TextId}{ProprietaryId}{"#text"};
	  }elsif($main_release->{ReleaseId}{ICPN}){
	  	$TXT{$release_reference}{external_id}=$irelease->{TextId}{ProprietaryId};
	  }
	  $TXT{$release_reference}{texttype}=$irelease->{TextType};
	  ## кто то передает массивом 
	  my @TxtDetailsByTerritory =  @{to_arrayref($irelease->{TextDetailsByTerritory})} ;
	  ## Title картинки 
  	 my @title= @{to_arrayref($irelease->{Title})} ;
  	 foreach my $itit ( @title ) {
  	 	if(ref($itit) eq 'HASH'){
  	 		#if($itit->{"-TitleType"} eq 'DisplayTitle'){
	  	   $TXT{$release_reference}{title}=$itit->{TitleText};
	  	  #}
	    }else{
	    	$TXT{$release_reference}{title} .="' " if $TXT{$release_reference}{title};
  	    $TXT{$release_reference}{title} .=$$itit;
	    }
  	 }
	  foreach my $rel_TDT (@TxtDetailsByTerritory){	  
  	 $TXT{$release_reference}{textcodectype}=$rel_TDT->{TechnicalTextDetails}{TextCodecType};
  	 $TXT{$release_reference}{filename}=$rel_TDT->{TechnicalTextDetails}{File}{FileName};
  	 $TXT{$release_reference}{path_to_file}=$rel_TDT->{TechnicalTextDetails}{File}{FilePath};
  	 $TXT{$release_reference}{md5}=$rel_TDT->{TechnicalTextDetails}{File}{HashSum}{HashSum};
  	 my @terr= @{to_arrayref($rel_TDT->{TerritoryCode})} ;
  	 foreach my $iterr ( @terr ) {
  	 	  $TXT{$release_reference}{territoria} .= ", " if $TXT{$release_reference}{territoria};
  	  	$TXT{$release_reference}{territoria} .= $iterr;
  	 }
  	} 
  	 $k++;
  }	
  print dumper \%TXT;
  foreach my $ikey(keys %TXT){
   my %IH=();
   foreach my $ivals (keys %{$TXT{$ikey}}){
   	  $IH{$ivals}=decode_utf8($TXT{$ikey}{$ivals});
   	}	
   	$IH{catalog_id}=$V::T{Catalog_id};
   	$IH{file_id}=$uuid;
   my @A=keys %IH;
   clear_row(\%IH);  
   print dumper \%IH; 
   next unless $IH{filename};
 
  }
  
 #  print dumper \%Prava;
 ### собираем все 
 foreach my $key (keys %Relise){
 	  foreach my $kdat (keys %{$Relise{$key}}){
 	     	$Tracks{$key}{$kdat}=$Relise{$key}{$kdat} if $Relise{$key}{$kdat};
 	  }
 }	
 foreach my $key (keys %Prava){
 	  foreach my $kdat (keys %{$Prava{$key}}){
 	     	$Tracks{$key}{$kdat}=$Prava{$key}{$kdat} if $Prava{$key}{$kdat};
 	  }
 }	
## чистим мусор
foreach my $key(keys %Tracks){
	foreach my $kdat (keys %{$Tracks{$key}}){
	 if(!defined($Tracks{$key}{$kdat})){ $Tracks{$key}{$kdat}=''; } 
	 $Tracks{$key}{$kdat} = decode_utf8($Tracks{$key}{$kdat});
	 $Tracks{$key}{$kdat} =~s/\&(amp;)+/\&/ig;
	 $Tracks{$key}{$kdat} = XML::Entities::decode("all",$Tracks{$key}{$kdat});
	}
}
 #print dumper \%Tracks;
 my $row_num=0;
 my @isrc;
 my $err=0;
 foreach my $key (sort{$a cmp $b} keys %Tracks){
 	 	 	print "$key | $Tracks{$key}{name_orig} |filename= $Tracks{$key}{filename} | md5= ".$Tracks{$key}{md5}."\n";
 	next unless $key;
 	next unless $Tracks{$key}{name_orig};
  my %ResData=();
  my %D=();
  ## добавляе worklist 
  if($Tracks{$key}{WorkListID}){
  	$Tracks{$key}{json_WorkList}=decode_utf8($WL{$Tracks{$key}{WorkListID}}{json_worklist});
  	foreach my $dkey (keys %{$WL{$Tracks{$key}{WorkListID}}{roles}}){
  		$Tracks{$key}{dolya} .= decode_utf8("$dkey: ".$WL{$Tracks{$key}{WorkListID}}{roles}{$dkey}{name}."\t".$WL{$Tracks{$key}{WorkListID}}{roles}{$dkey}{persent}."\%\n");
  	}
  }
  ## сопоставляем остальные данные 
  $ResData{author_text}=$Tracks{$key}{author_text};
  $ResData{author_music}=$Tracks{$key}{author_music};
  $ResData{performers}=$Tracks{$key}{performers};
  $ResData{album_name}=$Tracks{$key}{album_name};
  $ResData{duration}=$Tracks{$key}{duration};
  $ResData{publisher}=$Tracks{$key}{publisher};
  $ResData{public_year}=$Tracks{$key}{year};
  $ResData{isrc}=$Tracks{$key}{isrc};
  $ResData{isrc} =~ s/\-//g;
  $ResData{isrc} =~ s/\s//g;
   $err=1 unless $ResData{isrc};
  $ResData{territoria}=$Tracks{$key}{territory};
  $ResData{prava_from}=$Tracks{$key}{prava_from};
  $ResData{prava_to}=$Tracks{$key}{prava_to};
  $ResData{icpn}=$Tracks{$key}{icpn};
  $ResData{external_id}=$Tracks{$key}{external_id};
  $ResData{mp3_filename}=$Tracks{$key}{filename};
  $ResData{md5}=$Tracks{$key}{md5} if $Tracks{$key}{md5};
  $ResData{name_orig}=$Tracks{$key}{name_orig};
  $ResData{genre}=$Tracks{$key}{genre};
  $ResData{dolya}=$Tracks{$key}{dolya};
  if($Tracks{$key}{filename}){
  	$ResData{path_to_mp3_file}=$Tracks{$key}{filepath}."/".$Tracks{$key}{filename};
   }
  if($Tracks{$key}{URL}){
  	$ResData{path_to_mp3_file}=$Tracks{$key}{URL};
  }	
  $ResData{path_to_mp3_file} =~s/\/+/\//g;
  $ResData{file_id}=$uuid;
  $ResData{catalog_id}=$V::T{Catalog_id};
  my %JS=();
  eval{
   $JS{json_custom_prava}=from_json($Tracks{$key}{json_custom_prava});
   $D{json_custom_prava} =$JS{json_custom_prava};
  };
  
   eval{
   $JS{json_custom_sound}=from_json($Tracks{$key}{json_custom_sound});
 };
   eval{
   $JS{json_custom_track}=from_json($Tracks{$key}{json_custom_track});
  };
  eval{
   $JS{json_WorkList}=from_json($Tracks{$key}{json_WorkList});
  };
  eval{
   $JS{json_main_release}=from_json($Tracks{$key}{json_main_release});
  };
  
  $ResData{json_custom}=to_json(\%JS);
  $D{dealreleasereference}=$Tracks{$key}{dealreleasereference};
  # print "($key) dealreleasereference= $D{dealreleasereference} \n";
  $key =~/(\d+)/;
  $row_num =$1;
  $row_num++ unless $row_num;
  $ResData{row_num}=$row_num;
  clear_row(\%ResData);  
 print dumper \%ResData;
  my @A=keys %ResData;
  ## добавляем - обновляем данные в таблице в базе 
   my $it_in=$V::T{DB}->GetItems("select id from table where url='$url' and row_num=$row_num");	
 	 if(validate_uuid($it_in->[0][0])){
 	 	  $D{hgc_id}=$it_in->[0][0];
 			$V::T{DB}->update("table",\%ResData,\@A,"id='".$it_in->[0][0]."'");
 			#print dumper \%ResData;
 	 }else{
 			my $hgc=$V::T{DB}->insert("table",\%ResData,\@A,'','returning id');
 			$D{hgc_id}=$hgc->[0][0];
 	 }
 	
 
}
 	
return 1;
}
 
 
 #### === 
 sub clear_row{
 	my $H=shift;
 	foreach my $key (keys %{$H}){
 		$$H{$key} =~s/\'/\'\'/g;
   }
 	return 1;
 	}
 
 sub parse_releases_by_territory {
    my ( $xml_release ) = @_;
    my $by_territory = @{ to_arrayref($xml_release->{SoundRecordingDetailsByTerritory} ) }[0];
   return $by_territory ;
}

 sub parse_soundrecord {
    my ( $root ) = @_;
    state $releases = to_arrayref( $root->{ResourceList}{SoundRecording} );
    print  "No track releases found. Is this normal?" unless @$releases;
    return (  @$releases );
}
 
sub parse_releases {
    my ( $root ) = @_;

    state $releases = to_arrayref( $root->{ReleaseList}{Release} );

    state $main_releases = [
        grep {
            $_->{IsMainRelease} eq 'true'
            or
            $_->{ReleaseReference} eq 'R0'
        } @$releases
    ];

    print "Wrong number of main releases in file"  if @$main_releases != 1;

    state $track_releases = [
        grep {
            $_->{IsMainRelease} ne 'true'
                and
            $_->{ReleaseReference} ne 'R0'
        } @$releases
    ];

    print  "No track releases found. Is this normal?" unless @$track_releases;

    return ( $main_releases->[0], @$track_releases );
}

sub to_arrayref {
    my $variable = shift;
    return $variable if ref $variable eq 'ARRAY';
    return defined $variable ? [ $variable ] : [];
}
sub get_ProprietaryId {
    my $proprietary_id = shift;

    return  $proprietary_id            unless ref $proprietary_id;
    return $$proprietary_id            if     ref $proprietary_id eq 'SCALAR';
    return  $proprietary_id->{'#text'} if     ref $proprietary_id eq 'HASH';
}

sub get_isrc_from_ProprietaryId {
    my $proprietary_id = shift;
   # warn "# get_isrc_from_ProprietaryId: [$proprietary_id]";

    my ( $icpn_main_release, $isrc_track_release, $release_reference_track_release ) = $proprietary_id =~ /^(.+?)_(.+?)_(.+?)$/;
   # warn "# get_isrc_from_ProprietaryId: [$icpn_main_release], [$isrc_track_release], [$release_reference_track_release]";

    return $isrc_track_release;
}

=pod
Determine release external id.
It's either GRid or if there's no GRid, it's ProprietaryId.
=cut
sub determine_release_external_id {
    my ( $release ) = @_;

    my ( $release_reference ) = ( $release->{ReleaseReference} =~ /^R(\d+)/ );
 
    return $release->{ReleaseId}{GRid} if $release->{ReleaseId}{GRid};

    my $proprietary_id = $release->{ReleaseId}{ProprietaryId};

    return $proprietary_id            if ref $proprietary_id eq 'SCALAR';
    return $proprietary_id->{'#text'} if ref $proprietary_id eq 'HASH';

    # (1) Any main Release intended for consumers shall be identified by either a GRid or by an ICPN or by a ProprietaryID. Other identifiers may also be provided.
    if ( $release_reference == 0 ) {
        my $ispn = $release->{ReleaseId}{ICPN};

        return $ispn->{'#text'} if ref $ispn eq 'HASH';
        return $ispn if ref $ispn eq 'SCALAR';
    }
    
    return undef if ref $release->{ReleaseId}{ProprietaryId} ne 'ARRAY';

    my $first_id = $release->{ReleaseId}{ProprietaryId}->[0];
    return $first_id            if $first_id eq 'SCALAR';
    return $first_id->{'#text'} if $first_id eq 'HASH';

    return undef;
}

sub makeMD5{
 my $fname = shift;
 return if $fname eq '';
 open (my $fh, '<', $fname);
 binmode ($fh);
 my $md5 = Digest::MD5->new->addfile($fh)->hexdigest;
 close ($fh);
 return $md5;
}

sub validate_uuid {
    my  $uuid  = shift;
    return $uuid =~ /^[a-f0-9]{8}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{4}\-[a-f0-9]{12}$/i ? $uuid : undef;
}
