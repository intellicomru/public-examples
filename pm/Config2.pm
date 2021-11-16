package Config2;

use uni::perl qw/:dumper/;
use YAML::XS 'LoadFile';

our $VERSION = '0.02';

=head1 SYNOPSIS

use External::Config2;

my $config = External::Config2->new({
        dir     => 'pathtofile' // undef,       # path to config file, default is /spool/
        project => 'myproj' // undef,           # config file without '.yaml'
        })

Will read:
/pathtofile/myproj.yaml
config file.

Can read user environment:

CONFIG_PROJECT same as 'project' key

CONFIG_DIR path to config file

=cut

sub new {
    my $class = shift;
    my $cnf = { @_ };
    my $self = bless {
        dir     => $ENV{CONFIG_DIR}     || $cnf->{dir}    ;
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
