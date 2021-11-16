package Config2;

use uni::perl qw/:dumper/;
use YAML::XS 'LoadFile';

sub new {
    my $class = shift;
    my $cnf = { @_ };
    my $self = bless {
        dir     => $ENV{CONFIG_DIR}     || $cnf->{dir}    ,
        project => $ENV{CONFIG_PROJECT} || $cnf->{project},
    }, $class;

    $self->{dir} .= '/' unless ( $self->{dir}  =~ m#^.*/$#ig );
    $self->{project} =~ s#/##ig ;
    
    my $config_file = $self->{dir}.$self->{project}.'.yaml';
    unless (-e $config_file) {
    
            die 'ERROR!!! Can not load project config on: '.$config_file;
        
    }
    return $self->{ config } = LoadFile($config_file);
}

1;
