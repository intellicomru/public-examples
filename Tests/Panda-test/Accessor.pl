package Critter_Accessor;

use strict;

sub new {
    return bless
        defined $_[1]
            ? {%{$_[1]}} # make a copy of $fields.
            : {},
        ref $_[0] || $_[0];
}
 sub set {
    my($self, $key) = splice(@_, 0, 2);
 
    if(@_ == 1) {
        $self->{$key} = $_[0];
    }
    elsif(@_ > 1) {
        $self->{$key} = [@_];
    }
    else {
        $self->{error} = "Wrong number of arguments received";
    }
}
 
sub get {
    my $self = shift;
 
    if(@_ == 1) {
        return $self->{$_[0]};
    }
    elsif( @_ > 1 ) {
        return @{$self}{@_};
    }
    else {
         $self->{error} = "Wrong number of arguments received";
    }
}
 
sub make_accessor {
    my ($class, $field) = @_;
    return sub {
        my $self = shift;
 
        if(@_) {
            return $self->set($field, @_);
        } else {
            return $self->get($field);
        }
    };
}

  sub mk_accessors {
        my($self, @fields) = @_;
        my $class = ref $self || $self;
        no strict 'refs';
        foreach my $field (@fields) {
            my $accessor;
             $accessor = $self->make_accessor($field);
             my $fullname = "${class}::$field";
             unless (defined &{$fullname}) {
                    subname($fullname, $accessor) if defined &subname;
                    *{$fullname} = $accessor;
                }
        }
   }     
1;

package Critter;
 use base 'Critter_Accessor';
 Critter->mk_accessors(qw(color bomb));
sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
}
sub display {
    my $self  = shift;
    print $self->color, ' bomb: ', $self->bomb, ' ',  ref($self), "\n";
}

1;

package main;
my $c=Critter->new();
$c->color("blue");
$c->bomb("off");
$c->display;
$c->color("red");
$c->bomb("on");
$c->display;
$c->color("bad");
$c->display;
