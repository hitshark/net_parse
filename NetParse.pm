#!/usr/bin/perl

# function description
# parse the prototxt file to get the layer information
# of a network
# interface:
#   (%net, @layer_name) <= net_parse($file_name)
# the @layer_name array keeps the order of the layers

package NetParse 1.0;

use warnings;
use strict;

sub net_parse{
    my %net;            # the whole net info.
    my @layer_name;     # keep the layer name in order
    open(FIN, '<', $_[0]) or die "could not open $_ for $!\n";

    my $line;                   # a line from the protobuf file
    my $data_parse_done = 0;    # indicate the data parsing is done
    while($line = <FIN>){
        # parse the input data dimension
        if(($line =~ /^\s*input:\s*"data"/) || ($line =~ /^\s*top:\s*\"data\"/)){
            my %layer;          # for data input layer, use map data structure
            my @data_dim = ("batch", "channel_in", "height_in", "width_in");
            while(defined($line = <FIN>) && ($line !~ /^layer\s*\{/)){
                if($line =~ /^\s*input_param.*dim:\s*(\d+)\s*dim:\s*(\d+)\s*dim:\s*(\d+)\s*dim:\s*(\d+)/){
                    $layer{"batch"} = $1;
                    $layer{"channel_in"} = $2;
                    $layer{"height_in"} = $3;
                    $layer{"width_in"} = $4;
                }
                elsif($line =~ /^\s*input_dim:\s*(\d+)/){
                    my $name = shift @data_dim;
                    $layer{$name} = $1;
                }
                elsif($line =~ /^\s*dim:\s*(\d+)/){
                    my $name = shift @data_dim;
                    $layer{$name} = $1;
                }
            }
            $layer{"type"} = "Input";
            $layer{"name"} = "data";
            $net{"data"} = \%layer;
            push(@layer_name, "data");
            $data_parse_done = 1;
        }

        # parse each layer information
        if($data_parse_done && ($line =~ /^layer\s*\{/)){
            my @bottom;         # collect bottom layer name
            my $pad_h = 0;      # no padding in pooling, and pad field need to be initialized for calculation;
            my $pad_w = 0;
            my $stride_h = 1;   # some described files such as googlenet leave out this field;
            my $stride_w = 1;
            my $name;           # current layer name
            my $group;          # group for depth-wise convolution
            my %layer;          # for each layer, use map data structure
            my $type_done = 0;  # indicate if type field is parsed
            while(defined($line = <FIN>) && ($line !~ /^}\s*$/)){
                if($line =~ /^\s*bottom:\s*\"([\w_\/]+)\"/) {push(@bottom, $1);}
                elsif($line =~ /^\s*top:\s*\"([\w_\/]+)\"/) {$layer{"top"} = $1;}
                elsif($line =~ /^\s*name:\s*\"([\w_\/]+)\"/) {
                    $name = $1;
                    $layer{"name"} = $1;
                    push(@layer_name, $name);
                }
                elsif(!$type_done && ($line =~ /^\s*type:\s*\"([\w_\/]+)\"/)){
                    my $type = $1;
                    if($type eq "Convolution"){
                        if(defined($name) && ($name =~ /conv.*\/dw/)){
                            $type = "DepthWiseConv";
                        }
                    }
                    $layer{"type"} = $type;
                    $type_done = 1;
                }
                elsif($line =~ /^\s*num_output:\s*([\d]+)/) {$layer{"num_output"} = $1;}
                elsif($line =~ /^\s*group:\s*([\d]+)/) {
                    $group = $1;
                    if($group > 1) {$layer{"type"} = "DepthWiseConv";}
                }
                elsif($line =~ /^\s*pad:\s*([\d]+)/) {
                    $pad_h = $1;
                    $pad_w = $1;
                }
                elsif($line =~ /^\s*pad_h:\s*([\d]+)/) {$pad_h = $1;}
                elsif($line =~ /^\s*pad_w:\s*([\d]+)/) {$pad_w = $1;}

                elsif($line =~ /^\s*kernel_size:\s*([\d]+)/) {
                    $layer{"kernel_h"} = $1;
                    $layer{"kernel_w"} = $1;
                }
                elsif($line =~ /^\s*kernel_h:\s*([\d]+)/) {$layer{"kernel_h"} = $1;}
                elsif($line =~ /^\s*kernel_w:\s*([\d]+)/) {$layer{"kernel_w"} = $1;}

                elsif($line =~ /^\s*stride:\s*([\d]+)/) {
                    $stride_h = $1;
                    $stride_w = $1;
                }
                elsif($line =~ /^\s*stride_h:\s*([\d]+)/) {$stride_h = $1;}
                elsif($line =~ /^\s*stride_w:\s*([\d]+)/) {$stride_w = $1;}
            }
            $layer{"pad_h"} = $pad_h;
            $layer{"pad_w"} = $pad_w;
            $layer{"stride_h"} = $stride_h;
            $layer{"stride_w"} = $stride_w;
            $layer{"bottom"} = \@bottom;
            $net{$name} = \%layer;
        }
    }
    return (\%net, \@layer_name);
}

1;
